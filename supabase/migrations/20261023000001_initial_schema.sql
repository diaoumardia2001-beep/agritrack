-- ============================================================================
-- AgriTrack PostgreSQL / Supabase Migration
-- Migration 01: Schéma relationnel initial, contraintes, déclencheurs et bootstrap
-- Fichier: supabase/migrations/20261023000001_initial_schema.sql
-- ============================================================================

-- Activation de l'extension pgcrypto pour la génération des UUID (généralement préinstallée)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. Table: profiles (Profils utilisateurs synchronisés avec auth.users)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT NOT NULL DEFAULT 'Éleveur',
    phone_number TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_profiles_email_non_empty CHECK (char_length(trim(email)) > 0),
    CONSTRAINT chk_profiles_full_name_non_empty CHECK (char_length(trim(full_name)) > 0)
);

COMMENT ON TABLE public.profiles IS 'Profils publics minimaux des utilisateurs éleveurs, reliés à auth.users.';

-- ----------------------------------------------------------------------------
-- 2. Table: farms (Exploitations agricoles / élevages - unité multi-tenant)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.farms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    region TEXT,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    is_demo BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_farms_name_non_empty CHECK (char_length(trim(name)) > 0)
);

COMMENT ON TABLE public.farms IS 'Exploitations agricoles privées (unités de cloisonnement multi-tenant).';

-- ----------------------------------------------------------------------------
-- 3. Table: farm_members (Membres d''une exploitation et attribution des rôles)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.farm_members (
    farm_id UUID NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (farm_id, user_id),
    CONSTRAINT chk_farm_members_role CHECK (role IN ('owner', 'manager', 'worker'))
);

COMMENT ON TABLE public.farm_members IS 'Association multi-fermes des utilisateurs avec rôle spécifique par exploitation.';

-- ----------------------------------------------------------------------------
-- 4. Table: animals (Cheptel des animaux d''une exploitation)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.animals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    farm_id UUID NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
    local_id TEXT, -- Correspondance déterministe avec l'identifiant local Sembast (ex: a001, custom_uuid)
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    age_months INTEGER NOT NULL,
    weight_kg NUMERIC(6, 2) NOT NULL,
    health_status TEXT NOT NULL,
    image_url TEXT,
    is_demo BOOLEAN NOT NULL DEFAULT false,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ, -- Soft delete : préserve l'intégrité historique et comptable
    CONSTRAINT chk_animals_name_non_empty CHECK (char_length(trim(name)) > 0),
    CONSTRAINT chk_animals_type CHECK (type IN ('bovin', 'caprin', 'ovin', 'volaille')),
    CONSTRAINT chk_animals_age CHECK (age_months >= 0),
    CONSTRAINT chk_animals_weight CHECK (weight_kg > 0),
    CONSTRAINT chk_animals_health CHECK (health_status IN ('sain', 'a_surveiller', 'malade')),
    -- Clé composite essentielle pour garantir l'intégrité multi-tenant avec les dépenses :
    CONSTRAINT uq_animals_id_farm UNIQUE (id, farm_id)
);

-- Index unique partiel pour la correspondance locale sans collision entre exploitations
CREATE UNIQUE INDEX IF NOT EXISTS idx_animals_farm_local_id 
    ON public.animals (farm_id, local_id) 
    WHERE local_id IS NOT NULL;

COMMENT ON TABLE public.animals IS 'Animaux du cheptel avec soft delete et clé composite d''intégrité tenant.';

-- ----------------------------------------------------------------------------
-- 5. Table: expenses (Dépenses financières associées à un animal et une ferme)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    animal_id UUID NOT NULL,
    farm_id UUID NOT NULL,
    local_id TEXT, -- Correspondance déterministe avec l'identifiant local Sembast (ex: e001, exp_...)
    label TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    category TEXT NOT NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ, -- Soft delete : aucune perte financière involontaire
    CONSTRAINT chk_expenses_label_non_empty CHECK (char_length(trim(label)) > 0),
    CONSTRAINT chk_expenses_amount_positive CHECK (amount > 0),
    CONSTRAINT chk_expenses_category CHECK (category IN ('alimentation', 'sante', 'autre')),
    -- Contrainte d'intégrité multi-tenant forte :
    -- L'animal doit exister ET appartenir impérativement à la MÊME exploitation que la dépense :
    CONSTRAINT fk_expenses_animal_farm 
        FOREIGN KEY (animal_id, farm_id) 
        REFERENCES public.animals (id, farm_id) 
        ON DELETE RESTRICT
);

-- Index unique partiel pour la correspondance locale des dépenses
CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_farm_local_id 
    ON public.expenses (farm_id, local_id) 
    WHERE local_id IS NOT NULL;

COMMENT ON TABLE public.expenses IS 'Dépenses financières reliées à un animal avec verrouillage d''appartenance à la même exploitation.';

-- ----------------------------------------------------------------------------
-- 6. Index de performance pour requêtes courantes et synchronisation
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles (email);

CREATE INDEX IF NOT EXISTS idx_farms_owner_id ON public.farms (owner_id);

CREATE INDEX IF NOT EXISTS idx_farm_members_user ON public.farm_members (user_id);
CREATE INDEX IF NOT EXISTS idx_farm_members_farm_role ON public.farm_members (farm_id, role);

CREATE INDEX IF NOT EXISTS idx_animals_farm_active ON public.animals (farm_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_animals_sync ON public.animals (farm_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_animals_type ON public.animals (farm_id, type) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_expenses_farm_active ON public.expenses (farm_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_expenses_animal ON public.expenses (animal_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_expenses_sync ON public.expenses (farm_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON public.expenses (farm_id, date DESC);

-- ----------------------------------------------------------------------------
-- 7. Fonctions et Triggers d'automatisation (updated_at & Auth Sync)
-- ----------------------------------------------------------------------------

-- Fonction générique de mise à jour du champ updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Triggers updated_at sur toutes les tables
CREATE OR REPLACE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER trg_farms_updated_at
    BEFORE UPDATE ON public.farms
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER trg_farm_members_updated_at
    BEFORE UPDATE ON public.farm_members
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER trg_animals_updated_at
    BEFORE UPDATE ON public.animals
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER trg_expenses_updated_at
    BEFORE UPDATE ON public.expenses
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Trigger automatique de création de profil à l'inscription auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, phone_number, created_at, updated_at)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Éleveur'),
        NEW.raw_user_meta_data->>'phone_number',
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = CASE 
            WHEN profiles.full_name = 'Éleveur' AND EXCLUDED.full_name <> 'Éleveur' 
            THEN EXCLUDED.full_name 
            ELSE profiles.full_name 
        END,
        phone_number = COALESCE(EXCLUDED.phone_number, profiles.phone_number),
        updated_at = now();
    RETURN NEW;
END;
$$;

-- Déclencheur sur auth.users (présent dans Supabase)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 8. Procédure sécurisée : Création d'une exploitation avec propriétaire atomique
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_farm_with_owner(
    farm_name TEXT,
    farm_region TEXT DEFAULT NULL,
    is_demo_farm BOOLEAN DEFAULT FALSE
)
RETURNS public.farms
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    new_farm public.farms;
    current_user_id UUID;
BEGIN
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentification requise pour créer une exploitation.';
    END IF;

    IF farm_name IS NULL OR char_length(trim(farm_name)) = 0 THEN
        RAISE EXCEPTION 'Le nom de l''exploitation ne peut pas être vide.';
    END IF;

    -- 1. Insertion de la ferme avec owner_id verrouillé sur auth.uid()
    INSERT INTO public.farms (
        name,
        region,
        owner_id,
        is_demo,
        created_at,
        updated_at
    )
    VALUES (
        trim(farm_name),
        NULLIF(trim(farm_region), ''),
        current_user_id,
        is_demo_farm,
        now(),
        now()
    )
    RETURNING * INTO new_farm;

    -- 2. Insertion atomique du rôle 'owner' dans farm_members
    INSERT INTO public.farm_members (
        farm_id,
        user_id,
        role,
        created_at,
        updated_at
    )
    VALUES (
        new_farm.id,
        current_user_id,
        'owner',
        now(),
        now()
    );

    RETURN new_farm;
END;
$$;

COMMENT ON FUNCTION public.create_farm_with_owner IS 'Crée une exploitation et attache de façon atomique l''utilisateur connecté en tant qu''owner.';
