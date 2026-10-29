-- ============================================================================
-- AgriTrack — Suite de tests de sécurité SQL et validation des politiques RLS
-- Fichier: supabase/tests/security_tests.sql
-- ============================================================================
-- Ce script est conçu pour s'exécuter dans l'instance PostgreSQL Supabase locale.
-- Il utilise une transaction avec ROLLBACK final pour ne laisser aucune trace.
-- Il valide les 16 scénarios de sécurité et l'étanchéité stricte inter-fermes.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 0. Préparation de l'environnement de test (Identifiants et Fixtures)
-- ----------------------------------------------------------------------------

DO $$
BEGIN
    RAISE NOTICE '-------------------------------------------------------------';
    RAISE NOTICE '  AGRITRACK : VALIDATION DES POLITIQUES RLS ET INTEGRITE SQL';
    RAISE NOTICE '-------------------------------------------------------------';
END;
$$;

-- UUIDs fixes des acteurs et exploitations de test
CREATE TEMP TABLE temp_test_context (
    key TEXT PRIMARY KEY,
    id UUID NOT NULL
);

INSERT INTO temp_test_context (key, id) VALUES
    ('user_a', '11111111-1111-4111-8111-111111111111'::uuid), -- Éleveur A (Owner Ferme A)
    ('user_b', '22222222-2222-4222-8222-222222222222'::uuid), -- Éleveur B (Owner Ferme B)
    ('user_c', '33333333-3333-4333-8333-333333333333'::uuid), -- Ouvrier C (Worker Ferme A)
    ('user_m', '44444444-4444-4444-8444-444444444444'::uuid), -- Gestionnaire M (Manager Ferme A)
    ('farm_a', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid),
    ('farm_b', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid),
    ('animal_a', 'a1a1a1a1-a1a1-41a1-81a1-a1a1a1a1a1a1'::uuid),
    ('animal_b', 'b2b2b2b2-b2b2-42b2-82b2-b2b2b2b2b2b2'::uuid);

-- Insertion des utilisateurs de test dans la table réelle auth.users de Supabase
-- Le mot de passe crypté et les métadonnées respectent le format natif GoTrue/Supabase Auth
INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
)
VALUES 
    (
        (SELECT id FROM temp_test_context WHERE key = 'user_a'),
        '00000000-0000-0000-0000-000000000000'::uuid,
        'authenticated',
        'authenticated',
        'eleveur.a@agritrack.sn',
        crypt('TestPassword123!', gen_salt('bf')),
        now(),
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        '{"full_name": "Moussa Diop"}'::jsonb,
        now(),
        now()
    ),
    (
        (SELECT id FROM temp_test_context WHERE key = 'user_b'),
        '00000000-0000-0000-0000-000000000000'::uuid,
        'authenticated',
        'authenticated',
        'eleveur.b@agritrack.sn',
        crypt('TestPassword123!', gen_salt('bf')),
        now(),
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        '{"full_name": "Fatou Ndiaye"}'::jsonb,
        now(),
        now()
    ),
    (
        (SELECT id FROM temp_test_context WHERE key = 'user_c'),
        '00000000-0000-0000-0000-000000000000'::uuid,
        'authenticated',
        'authenticated',
        'ouvrier.c@agritrack.sn',
        crypt('TestPassword123!', gen_salt('bf')),
        now(),
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        '{"full_name": "Cheikh Sall"}'::jsonb,
        now(),
        now()
    ),
    (
        (SELECT id FROM temp_test_context WHERE key = 'user_m'),
        '00000000-0000-0000-0000-000000000000'::uuid,
        'authenticated',
        'authenticated',
        'gestionnaire.m@agritrack.sn',
        crypt('TestPassword123!', gen_salt('bf')),
        now(),
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        '{"full_name": "Awa Ba"}'::jsonb,
        now(),
        now()
    )
ON CONFLICT (id) DO NOTHING;

-- Insertion des exploitations agricoles de test
INSERT INTO public.farms (id, name, region, owner_id, is_demo)
VALUES 
    ((SELECT id FROM temp_test_context WHERE key = 'farm_a'), 'Ferme Diop Touba', 'Diourbel', (SELECT id FROM temp_test_context WHERE key = 'user_a'), false),
    ((SELECT id FROM temp_test_context WHERE key = 'farm_b'), 'Ferme Ndiaye Thiès', 'Thiès', (SELECT id FROM temp_test_context WHERE key = 'user_b'), false)
ON CONFLICT (id) DO NOTHING;

-- Attribution des rôles dans farm_members
INSERT INTO public.farm_members (farm_id, user_id, role)
VALUES 
    ((SELECT id FROM temp_test_context WHERE key = 'farm_a'), (SELECT id FROM temp_test_context WHERE key = 'user_a'), 'owner'),
    ((SELECT id FROM temp_test_context WHERE key = 'farm_a'), (SELECT id FROM temp_test_context WHERE key = 'user_m'), 'manager'),
    ((SELECT id FROM temp_test_context WHERE key = 'farm_a'), (SELECT id FROM temp_test_context WHERE key = 'user_c'), 'worker'),
    ((SELECT id FROM temp_test_context WHERE key = 'farm_b'), (SELECT id FROM temp_test_context WHERE key = 'user_b'), 'owner')
ON CONFLICT (farm_id, user_id) DO NOTHING;

-- Insertion des animaux initiaux
INSERT INTO public.animals (id, farm_id, name, type, age_months, weight_kg, health_status, created_by)
VALUES 
    ((SELECT id FROM temp_test_context WHERE key = 'animal_a'), (SELECT id FROM temp_test_context WHERE key = 'farm_a'), 'Taureau Moussa', 'bovin', 36, 420.0, 'sain', (SELECT id FROM temp_test_context WHERE key = 'user_a')),
    ((SELECT id FROM temp_test_context WHERE key = 'animal_b'), (SELECT id FROM temp_test_context WHERE key = 'farm_b'), 'Vache Fatou', 'bovin', 24, 310.0, 'sain', (SELECT id FROM temp_test_context WHERE key = 'user_b'))
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- FONCTIONS UTILITAIRES : Simulation réaliste de session et rôle Supabase
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_mock_auth_user(user_uuid UUID)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF user_uuid IS NULL THEN
        -- Simule un appelant anonyme (anon)
        PERFORM set_config('request.jwt.claims', '', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);
        PERFORM set_config('request.jwt.claim.role', 'anon', true);
        PERFORM set_config('role', 'anon', true);
    ELSE
        -- Simule un utilisateur authentifié avec son UID (authenticated)
        PERFORM set_config(
            'request.jwt.claims',
            json_build_object('sub', user_uuid::text, 'role', 'authenticated')::text,
            true
        );
        PERFORM set_config('request.jwt.claim.sub', user_uuid::text, true);
        PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
        PERFORM set_config('role', 'authenticated', true);
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION reset_mock_auth_user()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
    PERFORM set_config('request.jwt.claim.role', '', true);
    PERFORM set_config('role', 'none', true);
END;
$$;

-- Table de rapport pour compiler les résultats
CREATE TEMP TABLE test_results (
    test_number INT PRIMARY KEY,
    name TEXT NOT NULL,
    status TEXT NOT NULL,
    details TEXT
);

-- ============================================================================
-- TEST 1: Un utilisateur A ne peut pas lire les animaux de la ferme de B
-- ============================================================================
DO $$
DECLARE
    user_a UUID;
    farm_b UUID;
    visible_count INT;
BEGIN
    user_a := (SELECT id FROM temp_test_context WHERE key = 'user_a');
    farm_b := (SELECT id FROM temp_test_context WHERE key = 'farm_b');

    PERFORM set_mock_auth_user(user_a);

    SELECT count(*) INTO visible_count
    FROM public.animals
    WHERE farm_id = farm_b;

    PERFORM reset_mock_auth_user();

    IF visible_count = 0 THEN
        INSERT INTO test_results VALUES (1, 'Scénario 1: Isolation lecture animaux inter-fermes', 'PASS', 'User A voit 0 animal de la Ferme B (RLS actif)');
    ELSE
        INSERT INTO test_results VALUES (1, 'Scénario 1: Isolation lecture animaux inter-fermes', 'FAIL', 'User A a pu voir ' || visible_count || ' animaux de B');
    END IF;
END;
$$;

-- ============================================================================
-- TEST 2: Un utilisateur A ne peut pas créer un animal dans la ferme de B
-- ============================================================================
DO $$
DECLARE
    user_a UUID;
    farm_b UUID;
    inserted BOOLEAN := false;
BEGIN
    user_a := (SELECT id FROM temp_test_context WHERE key = 'user_a');
    farm_b := (SELECT id FROM temp_test_context WHERE key = 'farm_b');

    PERFORM set_mock_auth_user(user_a);

    BEGIN
        INSERT INTO public.animals (farm_id, name, type, age_months, weight_kg, health_status, created_by)
        VALUES (farm_b, 'Intrus Animal', 'caprin', 10, 20.0, 'sain', user_a);
        inserted := true;
    EXCEPTION 
        WHEN insufficient_privilege THEN
            inserted := false;
        WHEN others THEN
            inserted := false;
    END;

    PERFORM reset_mock_auth_user();

    IF NOT inserted THEN
        INSERT INTO test_results VALUES (2, 'Scénario 2: Blocage création animal inter-ferme', 'PASS', 'Insertion d''animal dans Ferme B par User A bloquée par RLS');
    ELSE
        INSERT INTO test_results VALUES (2, 'Scénario 2: Blocage création animal inter-ferme', 'FAIL', 'User A a réussi à insérer un animal dans Ferme B');
    END IF;
END;
$$;

-- ============================================================================
-- TEST 3: Un utilisateur A ne peut pas modifier ou supprimer les animaux de B
-- ============================================================================
DO $$
DECLARE
    user_a UUID;
    animal_b UUID;
    updated_rows INT;
    deleted_rows INT;
BEGIN
    user_a := (SELECT id FROM temp_test_context WHERE key = 'user_a');
    animal_b := (SELECT id FROM temp_test_context WHERE key = 'animal_b');

    PERFORM set_mock_auth_user(user_a);

    UPDATE public.animals SET name = 'Nom Piraté' WHERE id = animal_b;
    GET DIAGNOSTICS updated_rows = ROW_COUNT;

    DELETE FROM public.animals WHERE id = animal_b;
    GET DIAGNOSTICS deleted_rows = ROW_COUNT;

    PERFORM reset_mock_auth_user();

    IF updated_rows = 0 AND deleted_rows = 0 THEN
        INSERT INTO test_results VALUES (3, 'Scénario 3: Blocage modification/suppression inter-ferme', 'PASS', '0 ligne modifiée, 0 ligne supprimée (protégé par RLS)');
    ELSE
        INSERT INTO test_results VALUES (3, 'Scénario 3: Blocage modification/suppression inter-ferme', 'FAIL', 'Mise à jour: ' || updated_rows || ', Suppression: ' || deleted_rows);
    END IF;
END;
$$;

-- ============================================================================
-- TEST 4: Un worker ne peut pas s'attribuer le rôle owner
-- ============================================================================
DO $$
DECLARE
    user_c UUID;
    farm_a UUID;
    updated_rows INT;
BEGIN
    user_c := (SELECT id FROM temp_test_context WHERE key = 'user_c');
    farm_a := (SELECT id FROM temp_test_context WHERE key = 'farm_a');

    PERFORM set_mock_auth_user(user_c);

    UPDATE public.farm_members SET role = 'owner' WHERE farm_id = farm_a AND user_id = user_c;
    GET DIAGNOSTICS updated_rows = ROW_COUNT;

    PERFORM reset_mock_auth_user();

    IF updated_rows = 0 THEN
        INSERT INTO test_results VALUES (4, 'Scénario 4: Blocage escalade rôle worker vers owner', 'PASS', 'Worker C ne peut pas modifier son rôle vers owner (0 ligne affectée)');
    ELSE
        INSERT INTO test_results VALUES (4, 'Scénario 4: Blocage escalade rôle worker vers owner', 'FAIL', 'Le worker a pu s''attribuer le rôle owner !');
    END IF;
END;
$$;

-- ============================================================================
-- TEST 5: Un membre ne peut pas s'ajouter à une ferme sans autorisation
-- ============================================================================
DO $$
DECLARE
    user_b UUID;
    farm_a UUID;
    inserted BOOLEAN := false;
BEGIN
    user_b := (SELECT id FROM temp_test_context WHERE key = 'user_b');
    farm_a := (SELECT id FROM temp_test_context WHERE key = 'farm_a');

    PERFORM set_mock_auth_user(user_b);

    BEGIN
        INSERT INTO public.farm_members (farm_id, user_id, role)
        VALUES (farm_a, user_b, 'worker');
        inserted := true;
    EXCEPTION 
        WHEN insufficient_privilege THEN
            inserted := false;
        WHEN others THEN
            inserted := false;
    END;

    PERFORM reset_mock_auth_user();

    IF NOT inserted THEN
        INSERT INTO test_results VALUES (5, 'Scénario 5: Blocage auto-invitation non autorisée', 'PASS', 'User B ne peut pas s''ajouter dans Ferme A');
    ELSE
        INSERT INTO test_results VALUES (5, 'Scénario 5: Blocage auto-invitation non autorisée', 'FAIL', 'User B s''est auto-ajouté dans Ferme A');
    END IF;
END;
$$;

-- ============================================================================
-- TEST 6: Une dépense ne peut pas être associée à un animal d'une autre ferme
-- ============================================================================
DO $$
DECLARE
    user_a UUID;
    farm_a UUID;
    animal_b UUID;
    fk_rejected BOOLEAN := false;
BEGIN
    user_a := (SELECT id FROM temp_test_context WHERE key = 'user_a');
    farm_a := (SELECT id FROM temp_test_context WHERE key = 'farm_a');
    animal_b := (SELECT id FROM temp_test_context WHERE key = 'animal_b');

    PERFORM set_mock_auth_user(user_a);

    BEGIN
        -- Tenter d'associer Farm A avec Animal B (qui appartient à Farm B)
        INSERT INTO public.expenses (animal_id, farm_id, label, amount, date, category, created_by)
        VALUES (animal_b, farm_a, 'Aliment pirate', 5000.0, now(), 'alimentation', user_a);
    EXCEPTION 
        WHEN foreign_key_violation THEN
            fk_rejected := true;
        WHEN others THEN
            fk_rejected := false;
    END;

    PERFORM reset_mock_auth_user();

    IF fk_rejected THEN
        INSERT INTO test_results VALUES (6, 'Scénario 6: Intégrité FK composite dépense-animal-ferme', 'PASS', 'Contrainte composite (animal_id, farm_id) a rejeté l''incohérence inter-fermes');
    ELSE
        INSERT INTO test_results VALUES (6, 'Scénario 6: Intégrité FK composite dépense-animal-ferme', 'FAIL', 'Dépense créée avec animal d''une autre exploitation !');
    END IF;
END;
$$;

-- ============================================================================
-- TEST 7: Données privées inaccessibles aux utilisateurs non connectés (anon)
-- ============================================================================
DO $$
DECLARE
    access_blocked BOOLEAN := false;
    farm_count INT;
BEGIN
    -- Simulation utilisateur anonyme
    PERFORM set_mock_auth_user(NULL);

    BEGIN
        SELECT count(*) INTO farm_count FROM public.farms;
        IF farm_count = 0 THEN
            access_blocked := true;
        END IF;
    EXCEPTION WHEN others THEN
        -- Si l'accès est refusé au niveau privilèges (REVOKE ALL), c'est bloqué
        access_blocked := true;
    END;

    PERFORM reset_mock_auth_user();

    IF access_blocked THEN
        INSERT INTO test_results VALUES (7, 'Scénario 7: Étanchéité accès anonyme (anon)', 'PASS', 'Utilisateur non connecté voit 0 ligne ou accès refusé');
    ELSE
        INSERT INTO test_results VALUES (7, 'Scénario 7: Étanchéité accès anonyme (anon)', 'FAIL', 'Données privées visibles par anon');
    END IF;
END;
$$;

-- ============================================================================
-- TEST 8: Un utilisateur anonyme ne peut pas invoquer create_farm_with_owner
-- ============================================================================
DO $$
DECLARE
    call_blocked BOOLEAN := false;
    new_farm public.farms;
BEGIN
    PERFORM set_mock_auth_user(NULL);

    BEGIN
        SELECT * INTO new_farm FROM public.create_farm_with_owner('Ferme Fantôme Anon');
    EXCEPTION 
        WHEN insufficient_privilege THEN
            call_blocked := true;
        WHEN others THEN
            IF SQLERRM LIKE '%Authentification requise%' THEN
                call_blocked := true;
            END IF;
    END;

    PERFORM reset_mock_auth_user();

    IF call_blocked THEN
        INSERT INTO test_results VALUES (8, 'Scénario 8: Blocage appel privilégié par anon', 'PASS', 'Exécution de create_farm_with_owner bloquée pour les utilisateurs non authentifiés');
    ELSE
        INSERT INTO test_results VALUES (8, 'Scénario 8: Blocage appel privilégié par anon', 'FAIL', 'Un utilisateur anonyme a pu créer une exploitation !');
    END IF;
END;
$$;

-- ============================================================================
-- TEST 9: Un worker ne peut PAS modifier deleted_at (protection contre soft delete)
-- ============================================================================
DO $$
DECLARE
    user_c UUID;
    animal_a UUID;
    soft_delete_blocked BOOLEAN := false;
BEGIN
    user_c := (SELECT id FROM temp_test_context WHERE key = 'user_c');
    animal_a := (SELECT id FROM temp_test_context WHERE key = 'animal_a');

    PERFORM set_mock_auth_user(user_c);

    BEGIN
        -- Ouvrier C tente de soft-delete l'animal A
        UPDATE public.animals SET deleted_at = now() WHERE id = animal_a;
    EXCEPTION 
        WHEN insufficient_privilege THEN
            soft_delete_blocked := true;
        WHEN others THEN
            soft_delete_blocked := false;
    END;

    PERFORM reset_mock_auth_user();

    IF NOT soft_delete_blocked THEN
        IF (SELECT deleted_at FROM public.animals WHERE id = animal_a) IS NULL THEN
            soft_delete_blocked := true;
        END IF;
    END IF;

    IF soft_delete_blocked THEN
        INSERT INTO test_results VALUES (9, 'Scénario 4 bis: Interdiction soft-delete par un worker', 'PASS', 'Tentative de soft-delete par worker bloquée avec succès par WITH CHECK');
    ELSE
        INSERT INTO test_results VALUES (9, 'Scénario 4 bis: Interdiction soft-delete par un worker', 'FAIL', 'Le worker a pu marquer l''animal comme supprimé (deleted_at) !');
    END IF;
END;
$$;

-- ============================================================================
-- TEST 10: Interdiction de transférer un animal ou dépense vers une autre ferme
-- ============================================================================
DO $$
DECLARE
    user_c UUID;
    animal_a UUID;
    farm_b UUID;
    transfer_blocked BOOLEAN := false;
BEGIN
    user_c := (SELECT id FROM temp_test_context WHERE key = 'user_c');
    animal_a := (SELECT id FROM temp_test_context WHERE key = 'animal_a');
    farm_b := (SELECT id FROM temp_test_context WHERE key = 'farm_b');

    PERFORM set_mock_auth_user(user_c);

    BEGIN
        -- Tenter de transférer l'animal vers Farm B
        UPDATE public.animals SET farm_id = farm_b WHERE id = animal_a;
    EXCEPTION 
        WHEN insufficient_privilege THEN
            transfer_blocked := true;
        WHEN others THEN
            transfer_blocked := false;
    END;

    PERFORM reset_mock_auth_user();

    IF NOT transfer_blocked THEN
        IF (SELECT farm_id FROM public.animals WHERE id = animal_a) <> farm_b THEN
            transfer_blocked := true;
        END IF;
    END IF;

    IF transfer_blocked THEN
        INSERT INTO test_results VALUES (10, 'Scénario 10: Interdiction transfert de ferme (farm_id verrouillé)', 'PASS', 'Tentative de modification du farm_id bloquée par WITH CHECK');
    ELSE
        INSERT INTO test_results VALUES (10, 'Scénario 10: Interdiction transfert de ferme (farm_id verrouillé)', 'FAIL', 'L''animal a pu être transféré vers une autre exploitation !');
    END IF;
END;
$$;

-- ============================================================================
-- TEST 11: Un manager ne peut pas modifier les données réservées au propriétaire
-- ============================================================================
DO $$
DECLARE
    user_m UUID;
    farm_a UUID;
    updated_rows INT := 0;
    deleted_rows INT := 0;
BEGIN
    user_m := (SELECT id FROM temp_test_context WHERE key = 'user_m');
    farm_a := (SELECT id FROM temp_test_context WHERE key = 'farm_a');

    PERFORM set_mock_auth_user(user_m);

    -- Manager tente de modifier le nom de l'exploitation (réservé à l'owner)
    UPDATE public.farms SET name = 'Ferme Piratée par Manager' WHERE id = farm_a;
    GET DIAGNOSTICS updated_rows = ROW_COUNT;

    -- Manager tente de supprimer l'exploitation (réservé à l'owner)
    DELETE FROM public.farms WHERE id = farm_a;
    GET DIAGNOSTICS deleted_rows = ROW_COUNT;

    PERFORM reset_mock_auth_user();

    IF updated_rows = 0 AND deleted_rows = 0 THEN
        INSERT INTO test_results VALUES (11, 'Scénario 9: Actions réservées au propriétaire inaccessibles au manager', 'PASS', '0 modification et 0 suppression autorisée sur la table farms pour le manager');
    ELSE
        INSERT INTO test_results VALUES (11, 'Scénario 9: Actions réservées au propriétaire inaccessibles au manager', 'FAIL', 'Le manager a pu modifier ou supprimer la ferme (Update: ' || updated_rows || ', Delete: ' || deleted_rows || ')');
    END IF;
END;
$$;

-- ============================================================================
-- TEST 12: Opérations opérationnelles nominales autorisées pour chaque rôle
-- ============================================================================
DO $$
DECLARE
    user_a UUID;
    user_c UUID;
    farm_a UUID;
    animal_a UUID;
    worker_can_read BOOLEAN := false;
    worker_can_add_expense BOOLEAN := false;
    worker_can_update_weight BOOLEAN := false;
    owner_can_update_farm BOOLEAN := false;
    new_expense_id UUID;
    updated_animal_rows INT := 0;
    updated_farm_rows INT := 0;
BEGIN
    user_a := (SELECT id FROM temp_test_context WHERE key = 'user_a');
    user_c := (SELECT id FROM temp_test_context WHERE key = 'user_c');
    farm_a := (SELECT id FROM temp_test_context WHERE key = 'farm_a');
    animal_a := (SELECT id FROM temp_test_context WHERE key = 'animal_a');

    -- Test 12.1 : Worker C peut lire les animaux de sa ferme
    PERFORM set_mock_auth_user(user_c);
    SELECT EXISTS (SELECT 1 FROM public.animals WHERE farm_id = farm_a) INTO worker_can_read;

    -- Test 12.2 : Worker C peut mettre à jour le poids et l'état sanitaire (sans toucher deleted_at)
    UPDATE public.animals SET weight_kg = 425.5, health_status = 'sain' WHERE id = animal_a;
    GET DIAGNOSTICS updated_animal_rows = ROW_COUNT;
    worker_can_update_weight := (updated_animal_rows = 1);

    -- Test 12.3 : Worker C peut enregistrer une dépense légitime
    BEGIN
        INSERT INTO public.expenses (animal_id, farm_id, label, amount, date, category, created_by)
        VALUES (animal_a, farm_a, 'Foin quotidien', 3500.0, now(), 'alimentation', user_c)
        RETURNING id INTO new_expense_id;
        worker_can_add_expense := (new_expense_id IS NOT NULL);
    EXCEPTION WHEN others THEN
        worker_can_add_expense := false;
    END;

    -- Test 12.4 : Owner A peut mettre à jour les métadonnées de sa ferme
    PERFORM set_mock_auth_user(user_a);
    UPDATE public.farms SET region = 'Diourbel Nord' WHERE id = farm_a;
    GET DIAGNOSTICS updated_farm_rows = ROW_COUNT;
    owner_can_update_farm := (updated_farm_rows = 1);

    PERFORM reset_mock_auth_user();

    IF worker_can_read AND worker_can_update_weight AND worker_can_add_expense AND owner_can_update_farm THEN
        INSERT INTO test_results VALUES (12, 'Droits nominaux (Owner et Worker dans leurs prérogatives)', 'PASS', 'Worker peut lire, peser et créer une dépense ; Owner administre');
    ELSE
        INSERT INTO test_results VALUES (12, 'Droits nominaux (Owner et Worker dans leurs prérogatives)', 'FAIL', 'Lecture: ' || worker_can_read || ', Poids: ' || worker_can_update_weight || ', Dépense: ' || worker_can_add_expense || ', Owner: ' || owner_can_update_farm);
    END IF;
END;
$$;

-- ============================================================================
-- TEST 13: Création atomique exploitation + membre propriétaire via RPC
-- ============================================================================
DO $$
DECLARE
    user_a UUID;
    created_farm public.farms;
    member_record public.farm_members;
    atomic_success BOOLEAN := false;
    error_detail TEXT := '';
BEGIN
    user_a := (SELECT id FROM temp_test_context WHERE key = 'user_a');

    -- Simule l'éleveur authentifié A invoquant la fonction RPC
    PERFORM set_mock_auth_user(user_a);

    BEGIN
        SELECT * INTO created_farm
        FROM public.create_farm_with_owner(
            farm_name := 'Ferme Atomique Test',
            farm_region := 'Fatick',
            is_demo_farm := false
        );

        IF created_farm.id IS NOT NULL AND created_farm.owner_id = user_a THEN
            -- Vérifie que l'adhésion en tant que 'owner' a bien été insérée dans farm_members
            SELECT * INTO member_record
            FROM public.farm_members
            WHERE farm_id = created_farm.id AND user_id = user_a;

            IF member_record.role = 'owner' THEN
                atomic_success := true;
            ELSE
                error_detail := 'Membre créé mais rôle invalide : ' || COALESCE(member_record.role::text, 'aucun');
            END IF;
        ELSE
            error_detail := 'Ferme non créée ou owner_id erroné';
        END IF;
    EXCEPTION WHEN others THEN
        atomic_success := false;
        error_detail := 'Exception lors de l''appel RPC (' || SQLSTATE || ') : ' || SQLERRM;
    END;

    PERFORM reset_mock_auth_user();

    IF atomic_success THEN
        INSERT INTO test_results VALUES (
            13,
            'Création atomique d''exploitation via create_farm_with_owner',
            'PASS',
            'Ferme et appartenance propriétaire créées atomiquement dans la même transaction'
        );
    ELSE
        INSERT INTO test_results VALUES (
            13,
            'Création atomique d''exploitation via create_farm_with_owner',
            'FAIL',
            'Échec création atomique : ' || error_detail
        );
    END IF;
END;
$$;

-- ============================================================================
-- TEST 14: Interdiction formelle d'insertion directe dans la table farms
-- ============================================================================
DO $$
DECLARE
    user_a UUID;
    insert_denied BOOLEAN := false;
    error_detail TEXT := '';
BEGIN
    user_a := (SELECT id FROM temp_test_context WHERE key = 'user_a');

    -- Simule un utilisateur authentifié tentant une insertion directe hors RPC
    PERFORM set_mock_auth_user(user_a);

    BEGIN
        INSERT INTO public.farms (name, region, owner_id)
        VALUES ('Ferme Orpheline Directe', 'Thiès', user_a);

        insert_denied := false;
        error_detail := 'L''insertion directe a réussi alors qu''elle devait être refusée';
    EXCEPTION
        WHEN insufficient_privilege THEN
            insert_denied := true;
            error_detail := 'insufficient_privilege (rejet RLS attendu)';
        WHEN others THEN
            IF SQLSTATE = '42501' OR SQLERRM LIKE '%row-level security policy%' THEN
                insert_denied := true;
                error_detail := 'Rejet RLS attendu : ' || SQLERRM;
            ELSE
                insert_denied := false;
                error_detail := 'Erreur inattendue (' || SQLSTATE || ') : ' || SQLERRM;
            END IF;
    END;

    PERFORM reset_mock_auth_user();

    IF insert_denied THEN
        INSERT INTO test_results VALUES (
            14,
            'Interdiction d''insertion directe dans farms (authenticated)',
            'PASS',
            'Insertion directe bloquée par RLS : passage obligatoire par create_farm_with_owner'
        );
    ELSE
        INSERT INTO test_results VALUES (
            14,
            'Interdiction d''insertion directe dans farms (authenticated)',
            'FAIL',
            'Échec du blocage : ' || error_detail
        );
    END IF;
END;
$$;

-- ============================================================================
-- TEST 15: Révocation du privilège EXECUTE sur les fonctions de déclenchement
-- ============================================================================
DO $$
DECLARE
    has_priv_new_user BOOLEAN;
    has_priv_updated_at BOOLEAN;
BEGIN
    -- Utilisation de has_function_privilege car ces fonctions RETURNS TRIGGER
    -- ne peuvent pas être appelées directement hors contexte de déclencheur
    has_priv_new_user := has_function_privilege('authenticated', 'public.handle_new_user()', 'EXECUTE');
    has_priv_updated_at := has_function_privilege('authenticated', 'public.handle_updated_at()', 'EXECUTE');

    IF NOT has_priv_new_user AND NOT has_priv_updated_at THEN
        INSERT INTO test_results VALUES (
            15,
            'Révocation EXECUTE sur triggers (authenticated)',
            'PASS',
            'Privilèges EXECUTE correctement révoqués pour authenticated sur handle_new_user et handle_updated_at'
        );
    ELSE
        INSERT INTO test_results VALUES (
            15,
            'Révocation EXECUTE sur triggers (authenticated)',
            'FAIL',
            'Privilège EXECUTE résiduel détecté pour authenticated : handle_new_user=' || has_priv_new_user || ', handle_updated_at=' || has_priv_updated_at
        );
    END IF;
END;
$$;

-- ============================================================================
-- TEST 16: Privilèges par défaut durcis pour le rôle anon sur les futures tables
-- ============================================================================
DO $$
DECLARE
    anon_can_select BOOLEAN := true;
    anon_can_insert BOOLEAN := true;
BEGIN
    -- Création d'une nouvelle table par postgres dans le schéma public
    EXECUTE 'CREATE TABLE IF NOT EXISTS public.test_future_hardening_table (id int, val text)';

    -- Vérification des privilèges du rôle anon sur cette nouvelle table
    anon_can_select := has_table_privilege('anon', 'public.test_future_hardening_table', 'SELECT');
    anon_can_insert := has_table_privilege('anon', 'public.test_future_hardening_table', 'INSERT');

    -- Nettoyage propre immédiat
    EXECUTE 'DROP TABLE IF EXISTS public.test_future_hardening_table';

    IF NOT anon_can_select AND NOT anon_can_insert THEN
        INSERT INTO test_results VALUES (
            16,
            'Privilèges par défaut durcis sur nouvelles tables (anon)',
            'PASS',
            'Aucun privilège SELECT ou INSERT accordé par défaut au rôle anon sur les tables créées par postgres'
        );
    ELSE
        INSERT INTO test_results VALUES (
            16,
            'Privilèges par défaut durcis sur nouvelles tables (anon)',
            'FAIL',
            'Privilèges par défaut indésirables pour anon : SELECT=' || anon_can_select || ', INSERT=' || anon_can_insert
        );
    END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- Affichage du Bilan des Tests
-- ----------------------------------------------------------------------------
SELECT 
    test_number AS "N°",
    name AS "Épreuve de Sécurité",
    status AS "Résultat",
    details AS "Observations"
FROM test_results
ORDER BY test_number;

-- ----------------------------------------------------------------------------
-- Assertion stricte globale : échoue réellement si au moins un test est FAIL
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    failed_count INT;
    failed_details TEXT;
    total_passed INT;
BEGIN
    SELECT count(*), COALESCE(string_agg(test_number::text || ' (' || name || ')', ', '), '')
    INTO failed_count, failed_details
    FROM test_results
    WHERE status <> 'PASS';

    SELECT count(*) INTO total_passed FROM test_results WHERE status = 'PASS';

    IF failed_count > 0 OR total_passed <> 16 THEN
        RAISE EXCEPTION 'ASSERTION ÉCHOUÉE: % épreuve(s) ont échoué (%/16 réussies) : %', failed_count, total_passed, failed_details;
    ELSE
        RAISE NOTICE 'ASSERTION RÉUSSIE: Les 16 épreuves de sécurité ont réussi avec succès.';
    END IF;
END;
$$;

-- Rollback systématique pour laisser la base vierge de toute donnée de test
ROLLBACK;
