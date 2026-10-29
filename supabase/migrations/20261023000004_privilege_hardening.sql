-- ============================================================================
-- AgriTrack PostgreSQL / Supabase Migration
-- Migration 04: Révocation des privilèges superflus (TRUNCATE, TRIGGER, REFERENCES)
-- et verrouillage de l'insertion directe sur la table farms pour le rôle authenticated.
-- Fichier: supabase/migrations/20261023000004_privilege_hardening.sql
-- ============================================================================

-- 1. Révocation des privilèges TRUNCATE, TRIGGER et REFERENCES accordés à authenticated
-- Ces privilèges sont inutiles pour le client applicatif et présentent un risque de sécurité.
REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLE public.farms FROM authenticated;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLE public.farm_members FROM authenticated;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLE public.animals FROM authenticated;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLE public.expenses FROM authenticated;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLE public.profiles FROM authenticated;

-- 2. Verrouillage au niveau privilège de l'insertion directe sur farms
-- La création d'une ferme doit impérativement passer par la fonction RPC SECURITY DEFINER
-- create_farm_with_owner() qui associe farms et farm_members dans une même transaction.
REVOKE INSERT ON TABLE public.farms FROM authenticated;

-- 3. Durcissement des privilèges par défaut pour les futures tables
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLES FROM authenticated;
