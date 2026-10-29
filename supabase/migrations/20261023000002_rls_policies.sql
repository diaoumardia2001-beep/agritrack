-- ============================================================================
-- AgriTrack PostgreSQL / Supabase Migration
-- Migration 02: Politiques de sécurité RLS (Row Level Security) multi-fermes
-- Fichier: supabase/migrations/20261023000002_rls_policies.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Fonctions de contrôle d'accès SECURITY DEFINER (anti-récursion)
-- ----------------------------------------------------------------------------

-- Retourne le rôle d'un utilisateur connecté au sein d'une exploitation spécifique.
-- STABLE + search_path sécurisé : élimine la récursion RLS et protège contre l'injection de chemin.
CREATE OR REPLACE FUNCTION public.get_user_farm_role(target_farm_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    current_uid UUID;
    member_role TEXT;
BEGIN
    current_uid := auth.uid();
    IF current_uid IS NULL OR target_farm_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT role INTO member_role
    FROM public.farm_members
    WHERE farm_id = target_farm_id
      AND user_id = current_uid
    LIMIT 1;

    RETURN member_role;
END;
$$;

COMMENT ON FUNCTION public.get_user_farm_role IS 'Retourne le rôle du membre connecté dans l''exploitation cible (owner, manager, worker, ou NULL).';

-- Vérifie si l'utilisateur connecté appartient à l'exploitation avec l'un des rôles autorisés.
CREATE OR REPLACE FUNCTION public.is_farm_member(
    target_farm_id UUID, 
    allowed_roles TEXT[] DEFAULT ARRAY['owner', 'manager', 'worker']
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    current_uid UUID;
BEGIN
    current_uid := auth.uid();
    IF current_uid IS NULL OR target_farm_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.farm_members
        WHERE farm_id = target_farm_id
          AND user_id = current_uid
          AND role = ANY(allowed_roles)
    );
END;
$$;

-- Raccourci : vérifie si l'utilisateur est le propriétaire (owner) de l'exploitation.
CREATE OR REPLACE FUNCTION public.is_farm_owner(target_farm_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT public.get_user_farm_role(target_farm_id) = 'owner';
$$;

-- Raccourci : vérifie si l'utilisateur est gestionnaire ou propriétaire (manager ou owner).
CREATE OR REPLACE FUNCTION public.is_farm_manager_or_owner(target_farm_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT public.get_user_farm_role(target_farm_id) IN ('owner', 'manager');
$$;

-- ----------------------------------------------------------------------------
-- 2. Activation de RLS sur toutes les tables exposées
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.farms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.farm_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.animals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.farms FORCE ROW LEVEL SECURITY;
ALTER TABLE public.farm_members FORCE ROW LEVEL SECURITY;
ALTER TABLE public.animals FORCE ROW LEVEL SECURITY;
ALTER TABLE public.expenses FORCE ROW LEVEL SECURITY;

-- Verrouillage des accès par défaut pour anon (utilisateurs non authentifiés)
REVOKE ALL ON public.profiles FROM anon;
REVOKE ALL ON public.farms FROM anon;
REVOKE ALL ON public.farm_members FROM anon;
REVOKE ALL ON public.animals FROM anon;
REVOKE ALL ON public.expenses FROM anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.farms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.farm_members TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.animals TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expenses TO authenticated;

-- Verrouillage des fonctions et procédures stockées (principe du moindre privilège)
REVOKE EXECUTE ON FUNCTION public.handle_updated_at() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_user_farm_role(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_farm_member(UUID, TEXT[]) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_farm_owner(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_farm_manager_or_owner(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_farm_with_owner(TEXT, TEXT, BOOLEAN) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_user_farm_role(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_farm_member(UUID, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_farm_owner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_farm_manager_or_owner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_farm_with_owner(TEXT, TEXT, BOOLEAN) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. Politiques RLS: profiles
-- ----------------------------------------------------------------------------
-- Lecture : son propre profil OU profils des membres de la même exploitation
CREATE POLICY "profiles_select_own_or_co_members"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() = id
        OR EXISTS (
            SELECT 1 
            FROM public.farm_members fm_me
            JOIN public.farm_members fm_other ON fm_me.farm_id = fm_other.farm_id
            WHERE fm_me.user_id = auth.uid() 
              AND fm_other.user_id = profiles.id
        )
    );

-- Mise à jour : uniquement son propre profil, sans changer son id
CREATE POLICY "profiles_update_own"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Insertion : réservée au trigger auth ou à son propre compte
CREATE POLICY "profiles_insert_own"
    ON public.profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- 4. Politiques RLS: farms
-- ----------------------------------------------------------------------------
-- Lecture : réservée strictement aux membres de l'exploitation
CREATE POLICY "farms_select_members"
    ON public.farms
    FOR SELECT
    TO authenticated
    USING (
        public.is_farm_member(id, ARRAY['owner', 'manager', 'worker'])
    );

-- Insertion : l'utilisateur authentifié doit être déclaré comme owner_id
CREATE POLICY "farms_insert_owner"
    ON public.farms
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = owner_id
    );

-- Modification : seul le propriétaire de l'exploitation peut modifier ses paramètres
-- Le WITH CHECK empêche de transférer arbitrairement owner_id vers un autre compte
CREATE POLICY "farms_update_owner"
    ON public.farms
    FOR UPDATE
    TO authenticated
    USING (
        public.is_farm_owner(id)
    )
    WITH CHECK (
        public.is_farm_owner(id)
        AND owner_id = (SELECT f.owner_id FROM public.farms f WHERE f.id = farms.id)
    );

-- Suppression : seul le propriétaire peut supprimer l'exploitation
CREATE POLICY "farms_delete_owner"
    ON public.farms
    FOR DELETE
    TO authenticated
    USING (
        public.is_farm_owner(id)
    );

-- ----------------------------------------------------------------------------
-- 5. Politiques RLS: farm_members
-- ----------------------------------------------------------------------------
-- Lecture : les membres d'une exploitation peuvent voir la liste de leurs co-membres
CREATE POLICY "farm_members_select_farm_members"
    ON public.farm_members
    FOR SELECT
    TO authenticated
    USING (
        public.is_farm_member(farm_id, ARRAY['owner', 'manager', 'worker'])
    );

-- Insertion : seul le propriétaire de la ferme peut inviter ou ajouter des membres
-- Empêche qu'un tiers s'auto-ajoute ou s'attribue le rôle 'owner'
CREATE POLICY "farm_members_insert_owner_only"
    ON public.farm_members
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_farm_owner(farm_id)
        AND role IN ('manager', 'worker')
    );

-- Modification : seul l'owner peut modifier le rôle d'un membre (hors lui-même)
CREATE POLICY "farm_members_update_owner_only"
    ON public.farm_members
    FOR UPDATE
    TO authenticated
    USING (
        public.is_farm_owner(farm_id)
        AND user_id <> auth.uid()
    )
    WITH CHECK (
        public.is_farm_owner(farm_id)
        AND user_id <> auth.uid()
        AND role IN ('manager', 'worker')
    );

-- Suppression : 
-- L'owner peut révoquer un membre (hors lui-même pour ne pas rendre la ferme orpheline)
-- OU un membre (manager/worker) peut quitter volontairement l'exploitation
CREATE POLICY "farm_members_delete_owner_or_self"
    ON public.farm_members
    FOR DELETE
    TO authenticated
    USING (
        (public.is_farm_owner(farm_id) AND user_id <> auth.uid())
        OR (user_id = auth.uid() AND role <> 'owner')
    );

-- ----------------------------------------------------------------------------
-- 6. Politiques RLS: animals
-- ----------------------------------------------------------------------------
-- Lecture : tous les membres de la ferme (owner, manager, worker)
CREATE POLICY "animals_select_farm_members"
    ON public.animals
    FOR SELECT
    TO authenticated
    USING (
        public.is_farm_member(farm_id, ARRAY['owner', 'manager', 'worker'])
    );

-- Insertion : tous les membres actifs de la ferme peuvent enregistrer un animal
-- Le champ created_by doit correspondre à l'utilisateur connecté s'il est renseigné
CREATE POLICY "animals_insert_farm_members"
    ON public.animals
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_farm_member(farm_id, ARRAY['owner', 'manager', 'worker'])
        AND (created_by IS NULL OR created_by = auth.uid())
    );

-- Modification :
-- Tous les membres (owner, manager, worker) peuvent mettre à jour les données de l'animal
-- (ex: poids, statut sanitaire, nom), mais interdiction stricte de déplacer l'animal vers une autre ferme
-- et interdiction de modifier l'auteur initial (created_by).
CREATE POLICY "animals_update_farm_members"
    ON public.animals
    FOR UPDATE
    TO authenticated
    USING (
        public.is_farm_member(farm_id, ARRAY['owner', 'manager', 'worker'])
    )
    WITH CHECK (
        public.is_farm_member(farm_id, ARRAY['owner', 'manager', 'worker'])
        AND farm_id = (SELECT a.farm_id FROM public.animals a WHERE a.id = animals.id)
        AND (
            created_by IS NOT DISTINCT FROM (SELECT a.created_by FROM public.animals a WHERE a.id = animals.id)
        )
        AND (
            deleted_at IS NOT DISTINCT FROM (SELECT a.deleted_at FROM public.animals a WHERE a.id = animals.id)
            OR public.is_farm_manager_or_owner(farm_id)
        )
    );

-- Suppression (hard delete) ou marquage deleted_at par un worker interdit :
-- Seuls l'owner et le manager peuvent supprimer un animal
CREATE POLICY "animals_delete_owner_or_manager"
    ON public.animals
    FOR DELETE
    TO authenticated
    USING (
        public.is_farm_manager_or_owner(farm_id)
    );

-- ----------------------------------------------------------------------------
-- 7. Politiques RLS: expenses
-- ----------------------------------------------------------------------------
-- Lecture : tous les membres de la ferme
CREATE POLICY "expenses_select_farm_members"
    ON public.expenses
    FOR SELECT
    TO authenticated
    USING (
        public.is_farm_member(farm_id, ARRAY['owner', 'manager', 'worker'])
    );

-- Insertion : tous les membres actifs de la ferme peuvent enregistrer une dépense
CREATE POLICY "expenses_insert_farm_members"
    ON public.expenses
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_farm_member(farm_id, ARRAY['owner', 'manager', 'worker'])
        AND (created_by IS NULL OR created_by = auth.uid())
    );

-- Modification :
-- Seuls l'owner et le manager peuvent modifier une dépense financière existante.
-- Les ouvriers (workers) ne peuvent pas altérer a posteriori les montants comptabilisés.
-- Interdiction absolue de changer la ferme de rattachement.
CREATE POLICY "expenses_update_owner_or_manager"
    ON public.expenses
    FOR UPDATE
    TO authenticated
    USING (
        public.is_farm_manager_or_owner(farm_id)
    )
    WITH CHECK (
        public.is_farm_manager_or_owner(farm_id)
        AND farm_id = (SELECT e.farm_id FROM public.expenses e WHERE e.id = expenses.id)
        AND (
            created_by IS NOT DISTINCT FROM (SELECT e.created_by FROM public.expenses e WHERE e.id = expenses.id)
        )
    );

-- Suppression : seuls l'owner et le manager peuvent supprimer une dépense
CREATE POLICY "expenses_delete_owner_or_manager"
    ON public.expenses
    FOR DELETE
    TO authenticated
    USING (
        public.is_farm_manager_or_owner(farm_id)
    );
