-- ============================================================================
-- AgriTrack PostgreSQL / Supabase Migration
-- Migration 05: Contrôle de concurrence optimiste (version_id), RPC transactionnelles
-- et journal d'idempotence multi-tenant des opérations de synchronisation.
-- Fichier: supabase/migrations/20261027000001_optimistic_concurrency_and_idempotence.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Ajout des colonnes de versionnement monotone (version_id)
-- ----------------------------------------------------------------------------
-- Ajout additif et non destructif : valeur par défaut 1 pour toutes les lignes existantes.
ALTER TABLE public.animals 
    ADD COLUMN IF NOT EXISTS version_id INTEGER NOT NULL DEFAULT 1;

ALTER TABLE public.expenses 
    ADD COLUMN IF NOT EXISTS version_id INTEGER NOT NULL DEFAULT 1;

COMMENT ON COLUMN public.animals.version_id IS 'Version entière monotone pour le contrôle de concurrence optimiste multi-appareils.';
COMMENT ON COLUMN public.expenses.version_id IS 'Version entière monotone pour le contrôle de concurrence optimiste multi-appareils.';

-- ----------------------------------------------------------------------------
-- 2. Table d'idempotence des opérations de synchronisation
-- ----------------------------------------------------------------------------
-- Enregistre chaque opération appliquée et son résultat dans la même transaction
-- que la modification métier. Empêche l'exécution double après perte de réponse HTTP.
CREATE TABLE IF NOT EXISTS public.sync_operations_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    farm_id UUID NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    operation_id TEXT NOT NULL,
    entity_type TEXT NOT NULL CHECK (entity_type IN ('animal', 'expense')),
    action TEXT NOT NULL CHECK (action IN ('create', 'update', 'delete')),
    payload_hash TEXT NOT NULL,
    response_payload JSONB NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_sync_operations_farm_op_id UNIQUE (farm_id, operation_id)
);

COMMENT ON TABLE public.sync_operations_log IS 'Journal d''idempotence des mutations de synchronisation pour éliminer les doublons après déconnexion.';

-- Index de recherche et performance
CREATE INDEX IF NOT EXISTS idx_sync_operations_farm_applied 
    ON public.sync_operations_log (farm_id, applied_at DESC);

-- Sécurité RLS multi-tenant stricte
ALTER TABLE public.sync_operations_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_operations_log FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.sync_operations_log FROM anon;
REVOKE ALL ON public.sync_operations_log FROM PUBLIC;

GRANT SELECT ON public.sync_operations_log TO authenticated;

-- Seuls les membres de la ferme peuvent consulter le journal d'opérations de leur ferme
CREATE POLICY "sync_operations_select_farm_members"
    ON public.sync_operations_log
    FOR SELECT
    TO authenticated
    USING (
        public.is_farm_member(farm_id, ARRAY['owner', 'manager', 'worker'])
    );

-- ----------------------------------------------------------------------------
-- 3. Procédure transactionnelle optimiste : sync_push_animal
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_push_animal(
    p_operation_id TEXT,
    p_farm_id UUID,
    p_action TEXT,
    p_expected_version INTEGER DEFAULT NULL,
    p_local_id TEXT DEFAULT NULL,
    p_remote_id UUID DEFAULT NULL,
    p_name TEXT DEFAULT NULL,
    p_type TEXT DEFAULT NULL,
    p_age_months INTEGER DEFAULT NULL,
    p_weight_kg NUMERIC DEFAULT NULL,
    p_health_status TEXT DEFAULT NULL,
    p_image_url TEXT DEFAULT NULL,
    p_deleted_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
    current_uid UUID;
    user_role TEXT;
    v_payload_str TEXT;
    v_payload_hash TEXT;
    v_existing_op RECORD;
    v_existing_animal public.animals;
    v_target_animal public.animals;
    v_new_animal public.animals;
    v_updated_animal public.animals;
    v_deleted_animal public.animals;
    v_result JSONB;
BEGIN
    -- 1. Vérification de l'authentification
    current_uid := auth.uid();
    IF current_uid IS NULL THEN
        RAISE EXCEPTION 'Authentification requise pour synchroniser un animal.';
    END IF;

    -- 2. Validation des paramètres obligatoires
    IF p_operation_id IS NULL OR char_length(trim(p_operation_id)) = 0 THEN
        RAISE EXCEPTION 'operation_id est requis pour garantir l''idempotence.';
    END IF;

    IF p_farm_id IS NULL THEN
        RAISE EXCEPTION 'farm_id est requis.';
    END IF;

    IF p_action NOT IN ('create', 'update', 'delete') THEN
        RAISE EXCEPTION 'Action de synchronisation invalide: %', p_action;
    END IF;

    -- 3. Contrôle des droits multi-tenant côté serveur (ne fait jamais confiance au client)
    user_role := public.get_user_farm_role(p_farm_id);
    IF user_role IS NULL THEN
        RAISE EXCEPTION 'Accès refusé : vous n''êtes pas membre de l''exploitation %', p_farm_id;
    END IF;

    -- Un ouvrier (worker) ne peut pas supprimer un animal
    IF p_action = 'delete' AND user_role = 'worker' THEN
        RAISE EXCEPTION 'Permission refusée: un ouvrier ne peut pas supprimer un animal.';
    END IF;

    -- 4. Calcul du condensat cryptographique (hash SHA-256) pour détecter les réutilisations frauduleuses
    v_payload_str := p_action || '|' ||
                     COALESCE(p_expected_version::text, '') || '|' ||
                     COALESCE(p_local_id, '') || '|' ||
                     COALESCE(p_remote_id::text, '') || '|' ||
                     COALESCE(trim(p_name), '') || '|' ||
                     COALESCE(p_type, '') || '|' ||
                     COALESCE(p_age_months::text, '') || '|' ||
                     COALESCE(p_weight_kg::text, '') || '|' ||
                     COALESCE(p_health_status, '') || '|' ||
                     COALESCE(p_deleted_at::text, '');

    v_payload_hash := encode(digest(v_payload_str, 'sha256'), 'hex');

    -- 5. Vérification d'idempotence : opération déjà appliquée ?
    SELECT response_payload, payload_hash 
    INTO v_existing_op 
    FROM public.sync_operations_log
    WHERE farm_id = p_farm_id AND operation_id = p_operation_id;

    IF FOUND THEN
        IF v_existing_op.payload_hash <> v_payload_hash THEN
            RAISE EXCEPTION 'Conflit d''idempotence: l''operation_id "%" a déjà été exécutée avec un payload différent.', p_operation_id;
        END IF;

        -- Rejeu légitime : renvoyer le résultat original sans ré-appliquer la mutation
        RETURN v_existing_op.response_payload;
    END IF;

    -- 6. Exécution selon l'action
    IF p_action = 'create' THEN
        -- Vérification d'idempotence locale préalable sur (farm_id, local_id)
        IF p_local_id IS NOT NULL AND char_length(trim(p_local_id)) > 0 THEN
            SELECT * INTO v_existing_animal
            FROM public.animals
            WHERE farm_id = p_farm_id AND local_id = trim(p_local_id);

            IF FOUND THEN
                v_result := jsonb_build_object(
                    'status', 'success',
                    'action', 'create',
                    'id', v_existing_animal.id,
                    'remote_id', v_existing_animal.id,
                    'version_id', v_existing_animal.version_id,
                    'updated_at', v_existing_animal.updated_at
                );

                INSERT INTO public.sync_operations_log (
                    farm_id, user_id, operation_id, entity_type, action, payload_hash, response_payload
                ) VALUES (
                    p_farm_id, current_uid, p_operation_id, 'animal', 'create', v_payload_hash, v_result
                );

                RETURN v_result;
            END IF;
        END IF;

        IF p_name IS NULL OR char_length(trim(p_name)) = 0 THEN
            RAISE EXCEPTION 'Le nom de l''animal est obligatoire.';
        END IF;

        IF p_type IS NULL OR p_type NOT IN ('bovin', 'caprin', 'ovin', 'volaille') THEN
            RAISE EXCEPTION 'Type d''animal invalide : %', p_type;
        END IF;

        INSERT INTO public.animals (
            farm_id, local_id, name, type, age_months, weight_kg, health_status,
            image_url, is_demo, created_by, version_id, created_at, updated_at
        ) VALUES (
            p_farm_id,
            NULLIF(trim(p_local_id), ''),
            trim(p_name),
            p_type,
            COALESCE(p_age_months, 0),
            COALESCE(p_weight_kg, 1.0),
            COALESCE(p_health_status, 'sain'),
            p_image_url,
            false,
            current_uid,
            1,
            now(),
            now()
        )
        RETURNING * INTO v_new_animal;

        v_result := jsonb_build_object(
            'status', 'success',
            'action', 'create',
            'id', v_new_animal.id,
            'remote_id', v_new_animal.id,
            'version_id', v_new_animal.version_id,
            'updated_at', v_new_animal.updated_at
        );

    ELSIF p_action = 'update' THEN
        IF p_remote_id IS NULL THEN
            RAISE EXCEPTION 'remote_id est obligatoire pour une mise à jour d''animal.';
        END IF;

        IF p_expected_version IS NULL THEN
            RAISE EXCEPTION 'expected_version est obligatoire pour une mise à jour d''animal.';
        END IF;

        -- Verrouillage FOR UPDATE pour garantir la sérialisation stricte
        SELECT * INTO v_target_animal
        FROM public.animals
        WHERE id = p_remote_id AND farm_id = p_farm_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Animal introuvable sur cette exploitation (id: %).', p_remote_id;
        END IF;

        -- CONTRÔLE OPTIMISTE DE VERSION :
        IF v_target_animal.version_id <> p_expected_version THEN
            v_result := jsonb_build_object(
                'status', 'conflict',
                'action', 'update',
                'remote_id', v_target_animal.id,
                'server_version', v_target_animal.version_id,
                'expected_version', p_expected_version,
                'server_data', jsonb_build_object(
                    'id', v_target_animal.id,
                    'farm_id', v_target_animal.farm_id,
                    'local_id', v_target_animal.local_id,
                    'name', v_target_animal.name,
                    'type', v_target_animal.type,
                    'age_months', v_target_animal.age_months,
                    'weight_kg', v_target_animal.weight_kg,
                    'health_status', v_target_animal.health_status,
                    'image_url', v_target_animal.image_url,
                    'updated_at', v_target_animal.updated_at,
                    'deleted_at', v_target_animal.deleted_at,
                    'version_id', v_target_animal.version_id
                )
            );
            RETURN v_result;
        END IF;

        -- Application atomique et incrémentation stricte de version_id
        UPDATE public.animals
        SET name = COALESCE(NULLIF(trim(p_name), ''), name),
            type = COALESCE(p_type, type),
            age_months = COALESCE(p_age_months, age_months),
            weight_kg = COALESCE(p_weight_kg, weight_kg),
            health_status = COALESCE(p_health_status, health_status),
            image_url = CASE WHEN p_image_url IS NOT NULL THEN p_image_url ELSE image_url END,
            version_id = version_id + 1,
            updated_at = now()
        WHERE id = v_target_animal.id
        RETURNING * INTO v_updated_animal;

        v_result := jsonb_build_object(
            'status', 'success',
            'action', 'update',
            'id', v_updated_animal.id,
            'remote_id', v_updated_animal.id,
            'version_id', v_updated_animal.version_id,
            'updated_at', v_updated_animal.updated_at
        );

    ELSIF p_action = 'delete' THEN
        IF p_remote_id IS NULL THEN
            RAISE EXCEPTION 'remote_id est obligatoire pour supprimer logiquement un animal.';
        END IF;

        IF p_expected_version IS NULL THEN
            RAISE EXCEPTION 'expected_version est obligatoire pour supprimer logiquement un animal.';
        END IF;

        SELECT * INTO v_target_animal
        FROM public.animals
        WHERE id = p_remote_id AND farm_id = p_farm_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Animal introuvable sur cette exploitation (id: %).', p_remote_id;
        END IF;

        IF v_target_animal.version_id <> p_expected_version THEN
            v_result := jsonb_build_object(
                'status', 'conflict',
                'action', 'delete',
                'remote_id', v_target_animal.id,
                'server_version', v_target_animal.version_id,
                'expected_version', p_expected_version,
                'server_data', jsonb_build_object(
                    'id', v_target_animal.id,
                    'farm_id', v_target_animal.farm_id,
                    'local_id', v_target_animal.local_id,
                    'name', v_target_animal.name,
                    'type', v_target_animal.type,
                    'updated_at', v_target_animal.updated_at,
                    'deleted_at', v_target_animal.deleted_at,
                    'version_id', v_target_animal.version_id
                )
            );
            RETURN v_result;
        END IF;

        UPDATE public.animals
        SET deleted_at = COALESCE(p_deleted_at, now()),
            version_id = version_id + 1,
            updated_at = now()
        WHERE id = v_target_animal.id
        RETURNING * INTO v_deleted_animal;

        v_result := jsonb_build_object(
            'status', 'success',
            'action', 'delete',
            'id', v_deleted_animal.id,
            'remote_id', v_deleted_animal.id,
            'version_id', v_deleted_animal.version_id,
            'updated_at', v_deleted_animal.updated_at
        );
    END IF;

    -- 7. Consignation transactionnelle de l'opération appliquée
    INSERT INTO public.sync_operations_log (
        farm_id, user_id, operation_id, entity_type, action, payload_hash, response_payload
    ) VALUES (
        p_farm_id, current_uid, p_operation_id, 'animal', p_action, v_payload_hash, v_result
    );

    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.sync_push_animal IS 'RPC transactionnelle de synchronisation optimiste et idempotente pour les animaux.';

-- ----------------------------------------------------------------------------
-- 4. Procédure transactionnelle optimiste : sync_push_expense
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_push_expense(
    p_operation_id TEXT,
    p_farm_id UUID,
    p_action TEXT,
    p_expected_version INTEGER DEFAULT NULL,
    p_local_id TEXT DEFAULT NULL,
    p_remote_id UUID DEFAULT NULL,
    p_animal_id UUID DEFAULT NULL,
    p_label TEXT DEFAULT NULL,
    p_amount NUMERIC DEFAULT NULL,
    p_date TIMESTAMPTZ DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_deleted_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
    current_uid UUID;
    user_role TEXT;
    v_payload_str TEXT;
    v_payload_hash TEXT;
    v_existing_op RECORD;
    v_existing_expense public.expenses;
    v_target_expense public.expenses;
    v_new_expense public.expenses;
    v_updated_expense public.expenses;
    v_deleted_expense public.expenses;
    v_parent_animal public.animals;
    v_result JSONB;
BEGIN
    current_uid := auth.uid();
    IF current_uid IS NULL THEN
        RAISE EXCEPTION 'Authentification requise pour synchroniser une dépense.';
    END IF;

    IF p_operation_id IS NULL OR char_length(trim(p_operation_id)) = 0 THEN
        RAISE EXCEPTION 'operation_id est requis pour garantir l''idempotence.';
    END IF;

    IF p_farm_id IS NULL THEN
        RAISE EXCEPTION 'farm_id est requis.';
    END IF;

    IF p_action NOT IN ('create', 'update', 'delete') THEN
        RAISE EXCEPTION 'Action de synchronisation invalide: %', p_action;
    END IF;

    -- Contrôle des permissions multi-tenant côté serveur
    user_role := public.get_user_farm_role(p_farm_id);
    IF user_role IS NULL THEN
        RAISE EXCEPTION 'Accès refusé : vous n''êtes pas membre de l''exploitation %', p_farm_id;
    END IF;

    -- Seuls owner et manager peuvent modifier ou supprimer une dépense financière
    IF p_action IN ('update', 'delete') AND user_role = 'worker' THEN
        RAISE EXCEPTION 'Permission refusée: un ouvrier ne peut ni modifier ni supprimer une dépense.';
    END IF;

    v_payload_str := p_action || '|' ||
                     COALESCE(p_expected_version::text, '') || '|' ||
                     COALESCE(p_local_id, '') || '|' ||
                     COALESCE(p_remote_id::text, '') || '|' ||
                     COALESCE(p_animal_id::text, '') || '|' ||
                     COALESCE(trim(p_label), '') || '|' ||
                     COALESCE(p_amount::text, '') || '|' ||
                     COALESCE(p_date::text, '') || '|' ||
                     COALESCE(p_category, '') || '|' ||
                     COALESCE(p_deleted_at::text, '');

    v_payload_hash := encode(digest(v_payload_str, 'sha256'), 'hex');

    -- Vérification d'idempotence
    SELECT response_payload, payload_hash 
    INTO v_existing_op 
    FROM public.sync_operations_log
    WHERE farm_id = p_farm_id AND operation_id = p_operation_id;

    IF FOUND THEN
        IF v_existing_op.payload_hash <> v_payload_hash THEN
            RAISE EXCEPTION 'Conflit d''idempotence: l''operation_id "%" a déjà été exécutée avec un payload différent.', p_operation_id;
        END IF;

        RETURN v_existing_op.response_payload;
    END IF;

    IF p_action = 'create' THEN
        -- Vérification d'idempotence locale préalable sur (farm_id, local_id)
        IF p_local_id IS NOT NULL AND char_length(trim(p_local_id)) > 0 THEN
            SELECT * INTO v_existing_expense
            FROM public.expenses
            WHERE farm_id = p_farm_id AND local_id = trim(p_local_id);

            IF FOUND THEN
                v_result := jsonb_build_object(
                    'status', 'success',
                    'action', 'create',
                    'id', v_existing_expense.id,
                    'remote_id', v_existing_expense.id,
                    'version_id', v_existing_expense.version_id,
                    'updated_at', v_existing_expense.updated_at
                );

                INSERT INTO public.sync_operations_log (
                    farm_id, user_id, operation_id, entity_type, action, payload_hash, response_payload
                ) VALUES (
                    p_farm_id, current_uid, p_operation_id, 'expense', 'create', v_payload_hash, v_result
                );

                RETURN v_result;
            END IF;
        END IF;

        IF p_animal_id IS NULL THEN
            RAISE EXCEPTION 'animal_id est obligatoire pour créer une dépense.';
        END IF;

        -- Vérification que l'animal parent appartient bien à la même exploitation
        SELECT * INTO v_parent_animal
        FROM public.animals
        WHERE id = p_animal_id AND farm_id = p_farm_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Animal parent introuvable sur cette exploitation (animal_id: %).', p_animal_id;
        END IF;

        IF p_label IS NULL OR char_length(trim(p_label)) = 0 THEN
            RAISE EXCEPTION 'Le libellé de la dépense est obligatoire.';
        END IF;

        IF p_amount IS NULL OR p_amount <= 0 THEN
            RAISE EXCEPTION 'Le montant de la dépense doit être strictement positif.';
        END IF;

        IF p_category IS NULL OR p_category NOT IN ('alimentation', 'sante', 'autre') THEN
            RAISE EXCEPTION 'Catégorie de dépense invalide: %', p_category;
        END IF;

        INSERT INTO public.expenses (
            animal_id, farm_id, local_id, label, amount, date, category,
            created_by, version_id, created_at, updated_at
        ) VALUES (
            p_animal_id,
            p_farm_id,
            NULLIF(trim(p_local_id), ''),
            trim(p_label),
            p_amount,
            COALESCE(p_date, now()),
            p_category,
            current_uid,
            1,
            now(),
            now()
        )
        RETURNING * INTO v_new_expense;

        v_result := jsonb_build_object(
            'status', 'success',
            'action', 'create',
            'id', v_new_expense.id,
            'remote_id', v_new_expense.id,
            'version_id', v_new_expense.version_id,
            'updated_at', v_new_expense.updated_at
        );

    ELSIF p_action = 'update' THEN
        IF p_remote_id IS NULL THEN
            RAISE EXCEPTION 'remote_id est obligatoire pour modifier une dépense.';
        END IF;

        IF p_expected_version IS NULL THEN
            RAISE EXCEPTION 'expected_version est obligatoire pour modifier une dépense.';
        END IF;

        SELECT * INTO v_target_expense
        FROM public.expenses
        WHERE id = p_remote_id AND farm_id = p_farm_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Dépense introuvable sur cette exploitation (id: %).', p_remote_id;
        END IF;

        IF v_target_expense.version_id <> p_expected_version THEN
            v_result := jsonb_build_object(
                'status', 'conflict',
                'action', 'update',
                'remote_id', v_target_expense.id,
                'server_version', v_target_expense.version_id,
                'expected_version', p_expected_version,
                'server_data', jsonb_build_object(
                    'id', v_target_expense.id,
                    'animal_id', v_target_expense.animal_id,
                    'farm_id', v_target_expense.farm_id,
                    'local_id', v_target_expense.local_id,
                    'label', v_target_expense.label,
                    'amount', v_target_expense.amount,
                    'date', v_target_expense.date,
                    'category', v_target_expense.category,
                    'updated_at', v_target_expense.updated_at,
                    'deleted_at', v_target_expense.deleted_at,
                    'version_id', v_target_expense.version_id
                )
            );
            RETURN v_result;
        END IF;

        UPDATE public.expenses
        SET label = COALESCE(NULLIF(trim(p_label), ''), label),
            amount = COALESCE(p_amount, amount),
            date = COALESCE(p_date, date),
            category = COALESCE(p_category, category),
            version_id = version_id + 1,
            updated_at = now()
        WHERE id = v_target_expense.id
        RETURNING * INTO v_updated_expense;

        v_result := jsonb_build_object(
            'status', 'success',
            'action', 'update',
            'id', v_updated_expense.id,
            'remote_id', v_updated_expense.id,
            'version_id', v_updated_expense.version_id,
            'updated_at', v_updated_expense.updated_at
        );

    ELSIF p_action = 'delete' THEN
        IF p_remote_id IS NULL THEN
            RAISE EXCEPTION 'remote_id est obligatoire pour supprimer logiquement une dépense.';
        END IF;

        IF p_expected_version IS NULL THEN
            RAISE EXCEPTION 'expected_version est obligatoire pour supprimer logiquement une dépense.';
        END IF;

        SELECT * INTO v_target_expense
        FROM public.expenses
        WHERE id = p_remote_id AND farm_id = p_farm_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Dépense introuvable sur cette exploitation (id: %).', p_remote_id;
        END IF;

        IF v_target_expense.version_id <> p_expected_version THEN
            v_result := jsonb_build_object(
                'status', 'conflict',
                'action', 'delete',
                'remote_id', v_target_expense.id,
                'server_version', v_target_expense.version_id,
                'expected_version', p_expected_version,
                'server_data', jsonb_build_object(
                    'id', v_target_expense.id,
                    'animal_id', v_target_expense.animal_id,
                    'farm_id', v_target_expense.farm_id,
                    'local_id', v_target_expense.local_id,
                    'label', v_target_expense.label,
                    'amount', v_target_expense.amount,
                    'updated_at', v_target_expense.updated_at,
                    'deleted_at', v_target_expense.deleted_at,
                    'version_id', v_target_expense.version_id
                )
            );
            RETURN v_result;
        END IF;

        UPDATE public.expenses
        SET deleted_at = COALESCE(p_deleted_at, now()),
            version_id = version_id + 1,
            updated_at = now()
        WHERE id = v_target_expense.id
        RETURNING * INTO v_deleted_expense;

        v_result := jsonb_build_object(
            'status', 'success',
            'action', 'delete',
            'id', v_deleted_expense.id,
            'remote_id', v_deleted_expense.id,
            'version_id', v_deleted_expense.version_id,
            'updated_at', v_deleted_expense.updated_at
        );
    END IF;

    -- Consignation transactionnelle
    INSERT INTO public.sync_operations_log (
        farm_id, user_id, operation_id, entity_type, action, payload_hash, response_payload
    ) VALUES (
        p_farm_id, current_uid, p_operation_id, 'expense', p_action, v_payload_hash, v_result
    );

    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.sync_push_expense IS 'RPC transactionnelle de synchronisation optimiste et idempotente pour les dépenses.';

-- ----------------------------------------------------------------------------
-- 5. Privilèges stricts sur les fonctions RPC (Principe du moindre privilège)
-- ----------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.sync_push_animal(
    TEXT, UUID, TEXT, INTEGER, TEXT, UUID, TEXT, TEXT, INTEGER, NUMERIC, TEXT, TEXT, TIMESTAMPTZ
) FROM PUBLIC, anon;

REVOKE EXECUTE ON FUNCTION public.sync_push_expense(
    TEXT, UUID, TEXT, INTEGER, TEXT, UUID, UUID, TEXT, NUMERIC, TIMESTAMPTZ, TEXT, TIMESTAMPTZ
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.sync_push_animal(
    TEXT, UUID, TEXT, INTEGER, TEXT, UUID, TEXT, TEXT, INTEGER, NUMERIC, TEXT, TEXT, TIMESTAMPTZ
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.sync_push_expense(
    TEXT, UUID, TEXT, INTEGER, TEXT, UUID, UUID, TEXT, NUMERIC, TIMESTAMPTZ, TEXT, TIMESTAMPTZ
) TO authenticated;
