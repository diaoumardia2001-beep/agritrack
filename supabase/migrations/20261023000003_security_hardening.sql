-- ============================================================================
-- AgriTrack PostgreSQL / Supabase Migration
-- Migration 03: Durcissement de sécurité, atomicité multi-tenant et privilèges par défaut
-- Fichier: supabase/migrations/20261023000003_security_hardening.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Obligation d'utiliser create_farm_with_owner pour créer une exploitation
-- ----------------------------------------------------------------------------
-- Supprime la politique d'insertion directe sur la table farms.
-- Empêche qu'un utilisateur crée une exploitation orpheline sans membre owner associé.
-- Désormais, toute création de ferme doit impérativement passer par la fonction
-- atomique create_farm_with_owner() qui associe farms et farm_members dans une même transaction.
DROP POLICY IF EXISTS "farms_insert_owner" ON public.farms;

COMMENT ON TABLE public.farms IS 'Exploitations agricoles privées. La création d''une ferme passe obligatoirement par la fonction RPC atomique create_farm_with_owner.';

-- ----------------------------------------------------------------------------
-- 2. Révocation des privilèges EXECUTE résiduels sur les fonctions de déclenchement
-- ----------------------------------------------------------------------------
-- Les fonctions de trigger (RETURNS TRIGGER) sont invoquées en interne par PostgreSQL.
-- Par principe de moindre privilège, le rôle applicatif authenticated ne doit pas posséder
-- le privilège EXECUTE sur ces fonctions internes.
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_updated_at() FROM authenticated;

-- ----------------------------------------------------------------------------
-- 3. Durcissement des privilèges par défaut pour le rôle anon dans le schéma public
-- ----------------------------------------------------------------------------
-- Empêche Supabase d'accorder automatiquement tous les privilèges (arwdDxtm / EXECUTE)
-- au rôle anon sur les futures tables, fonctions et séquences créées par postgres dans public.
-- Les privilèges pour authenticated et service_role restent inchangés.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;
