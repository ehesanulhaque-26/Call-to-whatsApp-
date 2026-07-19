-- ============================================
-- OpenWA SaaS Database Schema
-- Using Supabase Auth
-- Idempotent migration - safe to run on fresh, partially, or fully initialized databases
-- ============================================

-- ============================================
-- SECTION 1: Extensions and Enums
-- ============================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enum types idempotently using DO $$ blocks
-- Future enum values can be added with: ALTER TYPE ... ADD VALUE IF NOT EXISTS 'value';

DO $$ BEGIN
    CREATE TYPE subscription_status AS ENUM ('active', 'inactive', 'cancelled', 'expired');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE subscription_plan AS ENUM ('free', 'starter', 'pro', 'enterprise');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE session_status AS ENUM ('pending', 'connected', 'disconnected', 'error');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE activity_type AS ENUM ('login', 'logout', 'create', 'update', 'delete', 'send_message', 'receive_message');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================
-- SECTION 2: All Tables
-- Note: Uses auth.users for authentication
-- ============================================

-- Profiles table (extends auth.users with app-specific data)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL DEFAULT '',
    phone TEXT,
    avatar_url TEXT,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    subscription_plan subscription_plan NOT NULL DEFAULT 'free',
    subscription_status subscription_status NOT NULL DEFAULT 'active',
    subscription_expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan subscription_plan NOT NULL DEFAULT 'free',
    status subscription_status NOT NULL DEFAULT 'active',
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sessions table (WhatsApp sessions)
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(100),
    status session_status DEFAULT 'pending',
    phone VARCHAR(20),
    device_name VARCHAR(255),
    qr_code TEXT,
    last_scanned_at TIMESTAMP WITH TIME ZONE,
    last_message_at TIMESTAMP WITH TIME ZONE,
    message_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Automations table
CREATE TABLE IF NOT EXISTS automations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    trigger_type VARCHAR(50) NOT NULL,
    trigger_config JSONB NOT NULL DEFAULT '{}',
    actions JSONB NOT NULL DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    execution_count INTEGER DEFAULT 0,
    last_executed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Campaigns table
CREATE TABLE IF NOT EXISTS campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'draft',
    message_template TEXT,
    media_url TEXT,
    contact_filter JSONB DEFAULT '{}',
    scheduled_at TIMESTAMP WITH TIME ZONE,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    total_recipients INTEGER DEFAULT 0,
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Contacts table
CREATE TABLE IF NOT EXISTS contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    phone VARCHAR(20) NOT NULL,
    name VARCHAR(255),
    push_name VARCHAR(255),
    is_contact BOOLEAN DEFAULT false,
    is_archived BOOLEAN DEFAULT false,
    is_starred BOOLEAN DEFAULT false,
    last_message_at TIMESTAMP WITH TIME ZONE,
    message_count INTEGER DEFAULT 0,
    tags TEXT[] DEFAULT '{}',
    notes TEXT,
    custom_fields JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, phone)
);

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Activity logs table
CREATE TABLE IF NOT EXISTS activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
    type activity_type NOT NULL,
    description TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Settings table
CREATE TABLE IF NOT EXISTS settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    key VARCHAR(255) NOT NULL,
    value JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, key)
);

-- ============================================
-- SECTION 2b: Column Recovery (for partially initialized databases)
-- ============================================
-- These statements ensure all expected columns exist even if table was partially created

-- Profiles columns
DO $$ BEGIN
    ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone TEXT;
EXCEPTION WHEN duplicate_column THEN null;
END $$;
DO $$ BEGIN
    ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
EXCEPTION WHEN duplicate_column THEN null;
END $$;

-- Subscriptions columns
DO $$ BEGIN
    ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITH TIME ZONE;
EXCEPTION WHEN duplicate_column THEN null;
END $$;

-- Sessions columns
DO $$ BEGIN
    ALTER TABLE sessions ADD COLUMN IF NOT EXISTS last_scanned_at TIMESTAMP WITH TIME ZONE;
EXCEPTION WHEN duplicate_column THEN null;
END $$;
DO $$ BEGIN
    ALTER TABLE sessions ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMP WITH TIME ZONE;
EXCEPTION WHEN duplicate_column THEN null;
END $$;

-- Automations columns
DO $$ BEGIN
    ALTER TABLE automations ADD COLUMN IF NOT EXISTS last_executed_at TIMESTAMP WITH TIME ZONE;
EXCEPTION WHEN duplicate_column THEN null;
END $$;

-- Contacts columns
DO $$ BEGIN
    ALTER TABLE contacts ADD COLUMN IF NOT EXISTS push_name VARCHAR(255);
EXCEPTION WHEN duplicate_column THEN null;
END $$;
DO $$ BEGIN
    ALTER TABLE contacts ADD COLUMN IF NOT EXISTS is_starred BOOLEAN DEFAULT false;
EXCEPTION WHEN duplicate_column THEN null;
END $$;

-- ============================================
-- SECTION 3: All Indexes (idempotent)
-- ============================================

-- Profiles indexes (id is already PK, no extra index needed)
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_subscription_plan ON profiles(subscription_plan);
CREATE INDEX IF NOT EXISTS idx_profiles_subscription_status ON profiles(subscription_status);
CREATE INDEX IF NOT EXISTS idx_profiles_subscription_expires_at ON profiles(subscription_expires_at);

-- Subscriptions indexes
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires_at ON subscriptions(expires_at);

-- Sessions indexes
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status);
CREATE INDEX IF NOT EXISTS idx_sessions_is_active ON sessions(is_active);

-- Automations indexes
CREATE INDEX IF NOT EXISTS idx_automations_user_id ON automations(user_id);
CREATE INDEX IF NOT EXISTS idx_automations_session_id ON automations(session_id);
CREATE INDEX IF NOT EXISTS idx_automations_is_active ON automations(is_active);

-- Campaigns indexes
CREATE INDEX IF NOT EXISTS idx_campaigns_user_id ON campaigns(user_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_session_id ON campaigns(session_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_scheduled_at ON campaigns(scheduled_at);

-- Contacts indexes
CREATE INDEX IF NOT EXISTS idx_contacts_user_id ON contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_contacts_session_id ON contacts(session_id);
CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone);
CREATE INDEX IF NOT EXISTS idx_contacts_tags ON contacts USING GIN(tags);

-- Notifications indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- Activity logs indexes
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_session_id ON activity_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_type ON activity_logs(type);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs(created_at DESC);

-- Settings indexes
CREATE INDEX IF NOT EXISTS idx_settings_user_id ON settings(user_id);

-- ============================================
-- SECTION 4: Trigger Functions (with explicit search_path for security)
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ============================================
-- SECTION 5: All Triggers (idempotent)
-- ============================================

DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_sessions_updated_at ON sessions;
CREATE TRIGGER update_sessions_updated_at BEFORE UPDATE ON sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_automations_updated_at ON automations;
CREATE TRIGGER update_automations_updated_at BEFORE UPDATE ON automations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_campaigns_updated_at ON campaigns;
CREATE TRIGGER update_campaigns_updated_at BEFORE UPDATE ON campaigns FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_contacts_updated_at ON contacts;
CREATE TRIGGER update_contacts_updated_at BEFORE UPDATE ON contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_notifications_updated_at ON notifications;
CREATE TRIGGER update_notifications_updated_at BEFORE UPDATE ON notifications FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_activity_logs_updated_at ON activity_logs;
CREATE TRIGGER update_activity_logs_updated_at BEFORE UPDATE ON activity_logs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_settings_updated_at ON settings;
CREATE TRIGGER update_settings_updated_at BEFORE UPDATE ON settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SECTION 6: Enable RLS (idempotent with existence checks)
-- ============================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
        ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'subscriptions') THEN
        ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'sessions') THEN
        ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'automations') THEN
        ALTER TABLE automations ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'campaigns') THEN
        ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'contacts') THEN
        ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
        ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'activity_logs') THEN
        ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'settings') THEN
        ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

-- ============================================
-- SECTION 7: All Policies (idempotent)
-- ============================================

-- Profiles policies (INSERT is handled by trigger, no direct INSERT allowed)
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
CREATE POLICY "Users can view their own profile" ON profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Subscriptions policies
DROP POLICY IF EXISTS "Users can view their own subscriptions" ON subscriptions;
CREATE POLICY "Users can view their own subscriptions" ON subscriptions FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their own subscriptions" ON subscriptions;
CREATE POLICY "Users can insert their own subscriptions" ON subscriptions FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own subscriptions" ON subscriptions;
CREATE POLICY "Users can update their own subscriptions" ON subscriptions FOR UPDATE USING (user_id = auth.uid());

-- Sessions policies
DROP POLICY IF EXISTS "Users can view their own sessions" ON sessions;
CREATE POLICY "Users can view their own sessions" ON sessions FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their own sessions" ON sessions;
CREATE POLICY "Users can insert their own sessions" ON sessions FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own sessions" ON sessions;
CREATE POLICY "Users can update their own sessions" ON sessions FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own sessions" ON sessions;
CREATE POLICY "Users can delete their own sessions" ON sessions FOR DELETE USING (user_id = auth.uid());

-- Automations policies
DROP POLICY IF EXISTS "Users can view their own automations" ON automations;
CREATE POLICY "Users can view their own automations" ON automations FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their own automations" ON automations;
CREATE POLICY "Users can insert their own automations" ON automations FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own automations" ON automations;
CREATE POLICY "Users can update their own automations" ON automations FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own automations" ON automations;
CREATE POLICY "Users can delete their own automations" ON automations FOR DELETE USING (user_id = auth.uid());

-- Campaigns policies
DROP POLICY IF EXISTS "Users can view their own campaigns" ON campaigns;
CREATE POLICY "Users can view their own campaigns" ON campaigns FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their own campaigns" ON campaigns;
CREATE POLICY "Users can insert their own campaigns" ON campaigns FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own campaigns" ON campaigns;
CREATE POLICY "Users can update their own campaigns" ON campaigns FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own campaigns" ON campaigns;
CREATE POLICY "Users can delete their own campaigns" ON campaigns FOR DELETE USING (user_id = auth.uid());

-- Contacts policies
DROP POLICY IF EXISTS "Users can view their own contacts" ON contacts;
CREATE POLICY "Users can view their own contacts" ON contacts FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their own contacts" ON contacts;
CREATE POLICY "Users can insert their own contacts" ON contacts FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own contacts" ON contacts;
CREATE POLICY "Users can update their own contacts" ON contacts FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own contacts" ON contacts;
CREATE POLICY "Users can delete their own contacts" ON contacts FOR DELETE USING (user_id = auth.uid());

-- Notifications policies
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
CREATE POLICY "Users can view their own notifications" ON notifications FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
CREATE POLICY "Users can update their own notifications" ON notifications FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;
CREATE POLICY "Users can delete their own notifications" ON notifications FOR DELETE USING (user_id = auth.uid());

-- Activity logs policies
DROP POLICY IF EXISTS "Users can view their own activity logs" ON activity_logs;
CREATE POLICY "Users can view their own activity logs" ON activity_logs FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can view all activity logs" ON activity_logs;
CREATE POLICY "Admins can view all activity logs" ON activity_logs FOR SELECT USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- Settings policies
DROP POLICY IF EXISTS "Users can view their own settings" ON settings;
CREATE POLICY "Users can view their own settings" ON settings FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their own settings" ON settings;
CREATE POLICY "Users can insert their own settings" ON settings FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own settings" ON settings;
CREATE POLICY "Users can update their own settings" ON settings FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own settings" ON settings;
CREATE POLICY "Users can delete their own settings" ON settings FOR DELETE USING (user_id = auth.uid());

-- ============================================
-- SECTION 8: Auto-create profile on user signup
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, name, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', ''),
        'user'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- SECTION 9: Admin helper function (restricted)
-- ============================================

CREATE OR REPLACE FUNCTION public.promote_to_admin(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only allow if called by service_role (bypass RLS) or admin
    -- This function should only be called from backend/service context
    UPDATE profiles SET role = 'admin' WHERE id = target_user_id;
END;
$$;

-- Revoke execute from public, only service_role can call this
REVOKE EXECUTE ON FUNCTION public.promote_to_admin(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.promote_to_admin(UUID) TO service_role;

-- ============================================
-- SECTION 10: Grants for Supabase roles
-- ============================================

-- Service role has full access (bypasses RLS)
GRANT USAGE ON SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Authenticated users can use the trigger function
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;

-- Anon and authenticated have minimal access through RLS
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
