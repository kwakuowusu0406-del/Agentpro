-- ============================================================
-- AGENT PRO GHANA — Complete Database Schema
-- PostgreSQL 15+
-- Version 2.0
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE user_role AS ENUM (
  'superuser', 'business_owner', 'manager', 'agent', 'auditor', 'customer'
);

CREATE TYPE account_status AS ENUM (
  'pending', 'active', 'suspended', 'deactivated'
);

CREATE TYPE provider AS ENUM ('mtn', 'telecel', 'at_money');

CREATE TYPE transaction_type AS ENUM (
  'cash_in', 'cash_out', 'send_money', 'merchant_payment',
  'bill_payment', 'airtime', 'data_bundle', 'balance_enquiry',
  'mini_statement', 'reversal'
);

CREATE TYPE transaction_status AS ENUM (
  'initiated', 'processing', 'success', 'failed', 'reversed', 'pending_confirmation'
);

CREATE TYPE subscription_plan AS ENUM ('free', 'business');

CREATE TYPE subscription_status AS ENUM (
  'pending', 'active', 'grace_period', 'suspended', 'cancelled'
);

CREATE TYPE payment_status AS ENUM (
  'pending', 'submitted', 'verified', 'rejected'
);

CREATE TYPE ad_status AS ENUM (
  'draft', 'pending_review', 'pending_payment', 'active', 'expired', 'rejected', 'suspended'
);

CREATE TYPE float_movement_type AS ENUM ('top_up', 'debit', 'adjustment');

CREATE TYPE notification_type AS ENUM (
  'transaction_success', 'transaction_failed', 'low_float',
  'subscription_reminder', 'subscription_expired', 'subscription_suspended',
  'ad_approved', 'ad_rejected', 'ad_expiring', 'ad_expired',
  'renewal_approved', 'new_user', 'system_update', 'float_request'
);

-- ============================================================
-- CORE TABLES
-- ============================================================

-- Companies (Business Owners' companies)
CREATE TABLE companies (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name              VARCHAR(255) NOT NULL,
  registration_number VARCHAR(100), -- Ghana Card or Business Registration
  phone             VARCHAR(20) NOT NULL,
  email             VARCHAR(255) NOT NULL UNIQUE,
  address           TEXT,
  logo_url          VARCHAR(500),
  status            account_status NOT NULL DEFAULT 'pending',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  approved_at       TIMESTAMPTZ,
  approved_by       UUID -- references users(id)
);

-- Users (All roles)
CREATE TABLE users (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id        UUID REFERENCES companies(id) ON DELETE SET NULL,
  role              user_role NOT NULL,
  first_name        VARCHAR(100) NOT NULL,
  last_name         VARCHAR(100) NOT NULL,
  email             VARCHAR(255) NOT NULL UNIQUE,
  phone             VARCHAR(20),
  password_hash     VARCHAR(255) NOT NULL,
  ghana_card_number VARCHAR(50),
  profile_image_url VARCHAR(500),
  status            account_status NOT NULL DEFAULT 'active',
  last_login_at     TIMESTAMPTZ,
  login_attempts    INTEGER NOT NULL DEFAULT 0,
  locked_until      TIMESTAMPTZ,
  fcm_token         VARCHAR(500), -- Firebase Cloud Messaging token
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by        UUID REFERENCES users(id)
);

-- Add FK after both tables exist
ALTER TABLE companies ADD CONSTRAINT fk_approved_by
  FOREIGN KEY (approved_by) REFERENCES users(id);

-- Branches
CREATE TABLE branches (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id        UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name              VARCHAR(255) NOT NULL,
  location          TEXT,
  phone             VARCHAR(20),
  status            account_status NOT NULL DEFAULT 'active',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by        UUID REFERENCES users(id)
);

-- Branch-Manager assignments (many-to-many: manager can manage multiple branches)
CREATE TABLE branch_managers (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  branch_id         UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  manager_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  assigned_by       UUID REFERENCES users(id),
  UNIQUE(branch_id, manager_id)
);

-- Agent-Branch assignments
CREATE TABLE agent_branches (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  branch_id         UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  assigned_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  assigned_by       UUID REFERENCES users(id),
  is_primary        BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE(agent_id, branch_id)
);

-- Password reset tokens
CREATE TABLE password_reset_tokens (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash        VARCHAR(255) NOT NULL,
  expires_at        TIMESTAMPTZ NOT NULL,
  used_at           TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Refresh tokens
CREATE TABLE refresh_tokens (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash        VARCHAR(255) NOT NULL,
  expires_at        TIMESTAMPTZ NOT NULL,
  revoked_at        TIMESTAMPTZ,
  device_info       JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- FLOAT MANAGEMENT
-- ============================================================

-- Float accounts per provider per branch
CREATE TABLE float_accounts (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  branch_id         UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  provider          provider NOT NULL,
  current_balance   DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  low_balance_threshold DECIMAL(15, 2) NOT NULL DEFAULT 500.00,
  last_updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(branch_id, provider)
);

-- Float movement history
CREATE TABLE float_movements (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  float_account_id  UUID NOT NULL REFERENCES float_accounts(id),
  movement_type     float_movement_type NOT NULL,
  amount            DECIMAL(15, 2) NOT NULL,
  balance_before    DECIMAL(15, 2) NOT NULL,
  balance_after     DECIMAL(15, 2) NOT NULL,
  reference         VARCHAR(255),
  notes             TEXT,
  performed_by      UUID NOT NULL REFERENCES users(id),
  approved_by       UUID REFERENCES users(id),
  transaction_id    UUID, -- links to transactions table
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Float requests (agent requests to manager)
CREATE TABLE float_requests (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  branch_id         UUID NOT NULL REFERENCES branches(id),
  requested_by      UUID NOT NULL REFERENCES users(id),
  provider          provider NOT NULL,
  amount_requested  DECIMAL(15, 2) NOT NULL,
  reason            TEXT,
  status            VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, approved, rejected
  reviewed_by       UUID REFERENCES users(id),
  reviewed_at       TIMESTAMPTZ,
  review_notes      TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TRANSACTIONS
-- ============================================================

CREATE TABLE transactions (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reference         VARCHAR(100) NOT NULL UNIQUE, -- internal ref
  network_reference VARCHAR(100), -- operator's transaction ID
  agent_id          UUID NOT NULL REFERENCES users(id),
  branch_id         UUID NOT NULL REFERENCES branches(id),
  company_id        UUID NOT NULL REFERENCES companies(id),
  provider          provider NOT NULL,
  transaction_type  transaction_type NOT NULL,
  status            transaction_status NOT NULL DEFAULT 'initiated',
  amount            DECIMAL(15, 2) NOT NULL,
  fee               DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  customer_phone    VARCHAR(20),
  customer_name     VARCHAR(255),
  recipient_phone   VARCHAR(20), -- for send money
  recipient_name    VARCHAR(255),
  biller_code       VARCHAR(100), -- for bill payments
  biller_name       VARCHAR(100),
  account_number    VARCHAR(100), -- for bill payments
  ussd_session_log  JSONB, -- USSD automation trace (no PIN logged)
  failure_reason    TEXT,
  notes             TEXT,
  receipt_url       VARCHAR(500), -- Cloudinary PDF URL
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at      TIMESTAMPTZ,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- USSD Templates (editable by Superuser without app update)
CREATE TABLE ussd_templates (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider          provider NOT NULL,
  transaction_type  transaction_type NOT NULL,
  name              VARCHAR(255) NOT NULL,
  ussd_code         VARCHAR(50) NOT NULL,
  menu_steps        JSONB NOT NULL, -- array of step definitions
  success_strings   TEXT[] NOT NULL, -- strings that indicate success
  failure_strings   TEXT[] NOT NULL, -- strings that indicate failure
  pin_step_index    INTEGER, -- which step index requires PIN (engine pauses here)
  timeout_seconds   INTEGER NOT NULL DEFAULT 30,
  retry_count       INTEGER NOT NULL DEFAULT 2,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  version           INTEGER NOT NULL DEFAULT 1,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by        UUID REFERENCES users(id),
  UNIQUE(provider, transaction_type)
);

-- ============================================================
-- COMMISSION SYSTEM
-- ============================================================

-- Global commission rules (set by Superuser)
CREATE TABLE commission_rules (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id        UUID REFERENCES companies(id), -- NULL = global default
  provider          provider,                       -- NULL = all providers
  transaction_type  transaction_type,               -- NULL = all types
  rate_percent      DECIMAL(5, 4) NOT NULL,         -- e.g., 0.0200 = 2%
  threshold_amount  DECIMAL(15, 2),                 -- cap kicks in above this
  cap_amount        DECIMAL(15, 2),                 -- max commission per transaction
  provider_share_percent DECIMAL(5, 4) NOT NULL DEFAULT 0.30, -- 30% to provider
  effective_from    DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to      DATE,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  approved_by       UUID REFERENCES users(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Commission records per transaction
CREATE TABLE commissions (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id    UUID NOT NULL REFERENCES transactions(id),
  agent_id          UUID NOT NULL REFERENCES users(id),
  branch_id         UUID NOT NULL REFERENCES branches(id),
  company_id        UUID NOT NULL REFERENCES companies(id),
  rule_id           UUID REFERENCES commission_rules(id),
  gross_commission  DECIMAL(15, 2) NOT NULL,
  provider_share    DECIMAL(15, 2) NOT NULL,
  net_commission    DECIMAL(15, 2) NOT NULL,
  calculated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Custom commission requests
CREATE TABLE commission_rule_requests (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id        UUID NOT NULL REFERENCES companies(id),
  requested_by      UUID NOT NULL REFERENCES users(id),
  proposed_rule     JSONB NOT NULL, -- proposed commission parameters
  reason            TEXT,
  status            VARCHAR(20) NOT NULL DEFAULT 'pending',
  reviewed_by       UUID REFERENCES users(id),
  reviewed_at       TIMESTAMPTZ,
  review_notes      TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SUBSCRIPTION SYSTEM
-- ============================================================

CREATE TABLE subscriptions (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id        UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  plan              subscription_plan NOT NULL DEFAULT 'free',
  status            subscription_status NOT NULL DEFAULT 'pending',
  amount            DECIMAL(10, 2) NOT NULL DEFAULT 10.00, -- GH₵
  started_at        TIMESTAMPTZ,
  expires_at        TIMESTAMPTZ,
  grace_period_ends_at TIMESTAMPTZ,
  cancelled_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Subscription payment submissions
CREATE TABLE subscription_payments (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subscription_id   UUID NOT NULL REFERENCES subscriptions(id),
  company_id        UUID NOT NULL REFERENCES companies(id),
  amount            DECIMAL(10, 2) NOT NULL,
  momo_reference    VARCHAR(100) NOT NULL, -- MTN MoMo reference submitted by user
  payment_phone     VARCHAR(20), -- phone that sent payment
  status            payment_status NOT NULL DEFAULT 'pending',
  submitted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified_at       TIMESTAMPTZ,
  verified_by       UUID REFERENCES users(id),
  rejection_reason  TEXT,
  period_months     INTEGER NOT NULL DEFAULT 1,
  notes             TEXT
);

-- Subscription pricing config (managed by Superuser)
CREATE TABLE system_config (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key               VARCHAR(100) NOT NULL UNIQUE,
  value             TEXT NOT NULL,
  description       TEXT,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by        UUID REFERENCES users(id)
);

-- ============================================================
-- MARKETPLACE
-- ============================================================

CREATE TABLE ad_categories (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name              VARCHAR(100) NOT NULL UNIQUE,
  icon              VARCHAR(100),
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE advertisements (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id        UUID REFERENCES companies(id),
  posted_by         UUID NOT NULL REFERENCES users(id),
  category_id       UUID REFERENCES ad_categories(id),
  title             VARCHAR(255) NOT NULL,
  description       TEXT NOT NULL,
  price             DECIMAL(15, 2),
  currency          VARCHAR(10) NOT NULL DEFAULT 'GHS',
  location          VARCHAR(255),
  contact_phone     VARCHAR(20),
  contact_email     VARCHAR(255),
  image_urls        TEXT[],
  video_url         VARCHAR(500),
  status            ad_status NOT NULL DEFAULT 'draft',
  rejection_reason  TEXT,
  publishing_fee    DECIMAL(10, 2), -- calculated as 1% of price
  fee_percent       DECIMAL(5, 4) NOT NULL DEFAULT 0.01, -- captured at time of posting
  published_at      TIMESTAMPTZ,
  expires_at        TIMESTAMPTZ,
  grace_period_ends_at TIMESTAMPTZ,
  views_count       INTEGER NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ad payment submissions
CREATE TABLE ad_payments (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  advertisement_id  UUID NOT NULL REFERENCES advertisements(id),
  posted_by         UUID NOT NULL REFERENCES users(id),
  amount            DECIMAL(10, 2) NOT NULL,
  momo_reference    VARCHAR(100) NOT NULL,
  payment_phone     VARCHAR(20),
  status            payment_status NOT NULL DEFAULT 'pending',
  submitted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  verified_at       TIMESTAMPTZ,
  verified_by       UUID REFERENCES users(id),
  rejection_reason  TEXT
);

-- Ad ratings and reviews
CREATE TABLE ad_ratings (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  advertisement_id  UUID NOT NULL REFERENCES advertisements(id),
  rated_by          UUID NOT NULL REFERENCES users(id),
  rating            SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  review            TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(advertisement_id, rated_by)
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

CREATE TABLE notifications (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type              notification_type NOT NULL,
  title             VARCHAR(255) NOT NULL,
  body              TEXT NOT NULL,
  data              JSONB, -- extra payload
  is_read           BOOLEAN NOT NULL DEFAULT FALSE,
  read_at           TIMESTAMPTZ,
  sent_at           TIMESTAMPTZ,
  fcm_message_id    VARCHAR(255),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- AI ASSISTANT
-- ============================================================

CREATE TABLE ai_conversations (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title             VARCHAR(255),
  context           JSONB, -- user role, company context
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE ai_messages (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id   UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
  role              VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
  content           TEXT NOT NULL,
  tokens_used       INTEGER,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- AI Knowledge base (Superuser managed)
CREATE TABLE ai_knowledge_base (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category          VARCHAR(100) NOT NULL,
  title             VARCHAR(255) NOT NULL,
  content           TEXT NOT NULL,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by        UUID REFERENCES users(id)
);

-- ============================================================
-- AUDIT LOGGING
-- ============================================================

CREATE TABLE audit_logs (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID REFERENCES users(id),
  company_id        UUID REFERENCES companies(id),
  action            VARCHAR(255) NOT NULL,
  entity_type       VARCHAR(100), -- 'transaction', 'user', 'float', etc.
  entity_id         UUID,
  old_values        JSONB,
  new_values        JSONB,
  ip_address        INET,
  user_agent        TEXT,
  request_id        UUID,
  result            VARCHAR(20) NOT NULL DEFAULT 'success', -- success, failure
  error_message     TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

-- Users
CREATE INDEX idx_users_company_id ON users(company_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);

-- Transactions
CREATE INDEX idx_transactions_agent_id ON transactions(agent_id);
CREATE INDEX idx_transactions_branch_id ON transactions(branch_id);
CREATE INDEX idx_transactions_company_id ON transactions(company_id);
CREATE INDEX idx_transactions_provider ON transactions(provider);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);
CREATE INDEX idx_transactions_type ON transactions(transaction_type);
CREATE INDEX idx_transactions_customer_phone ON transactions(customer_phone);

-- Float
CREATE INDEX idx_float_movements_account_id ON float_movements(float_account_id);
CREATE INDEX idx_float_movements_created_at ON float_movements(created_at);

-- Commissions
CREATE INDEX idx_commissions_agent_id ON commissions(agent_id);
CREATE INDEX idx_commissions_company_id ON commissions(company_id);
CREATE INDEX idx_commissions_transaction_id ON commissions(transaction_id);

-- Notifications
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- Audit Logs
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_company_id ON audit_logs(company_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

-- Advertisements
CREATE INDEX idx_advertisements_status ON advertisements(status);
CREATE INDEX idx_advertisements_category_id ON advertisements(category_id);
CREATE INDEX idx_advertisements_posted_by ON advertisements(posted_by);

-- AI
CREATE INDEX idx_ai_messages_conversation_id ON ai_messages(conversation_id);

-- ============================================================
-- INITIAL SEED DATA
-- ============================================================

-- System configuration defaults
INSERT INTO system_config (key, value, description) VALUES
  ('subscription_monthly_price', '10.00', 'Monthly subscription price in GHS'),
  ('subscription_grace_period_days', '7', 'Days after expiry before suspension'),
  ('ad_fee_percent', '0.01', 'Advertisement publishing fee (1% of price)'),
  ('ad_duration_days', '30', 'Advertisement active duration in days'),
  ('ad_grace_period_days', '7', 'Days after expiry before ad removed'),
  ('agent_pro_momo_number', '', 'MTN MoMo merchant number for payments'),
  ('max_login_attempts', '5', 'Max failed login attempts before lockout'),
  ('lockout_duration_minutes', '30', 'Account lockout duration in minutes'),
  ('jwt_access_expiry_minutes', '15', 'JWT access token expiry in minutes'),
  ('jwt_refresh_expiry_days', '30', 'JWT refresh token expiry in days'),
  ('low_float_default_threshold', '500.00', 'Default low float alert threshold in GHS');

-- Ad categories
INSERT INTO ad_categories (name, icon) VALUES
  ('Mobile Money Services', 'mobile_money'),
  ('Electronics', 'electronics'),
  ('Clothing & Accessories', 'clothing'),
  ('Food & Beverages', 'food'),
  ('Real Estate', 'real_estate'),
  ('Vehicles', 'vehicles'),
  ('Services', 'services'),
  ('Agriculture', 'agriculture'),
  ('Health & Beauty', 'health'),
  ('Education', 'education'),
  ('Jobs & Recruitment', 'jobs'),
  ('Other', 'other');

-- Default global commission rule (example)
-- Rate: 2%, Threshold: GHS 1000, Cap: GHS 20, Provider Share: 30%
-- INSERT INTO commission_rules (rate_percent, threshold_amount, cap_amount, provider_share_percent)
-- VALUES (0.0200, 1000.00, 20.00, 0.30);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Auto-update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all relevant tables
CREATE TRIGGER trg_companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_branches_updated_at BEFORE UPDATE ON branches FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_float_accounts_updated_at BEFORE UPDATE ON float_accounts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_transactions_updated_at BEFORE UPDATE ON transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_advertisements_updated_at BEFORE UPDATE ON advertisements FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_ai_conversations_updated_at BEFORE UPDATE ON ai_conversations FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Function to calculate commission for a transaction
CREATE OR REPLACE FUNCTION calculate_commission(
  p_amount DECIMAL,
  p_rate DECIMAL,
  p_threshold DECIMAL,
  p_cap DECIMAL,
  p_provider_share DECIMAL
) RETURNS TABLE(gross DECIMAL, provider DECIMAL, net DECIMAL) AS $$
DECLARE
  v_gross DECIMAL;
BEGIN
  v_gross := p_amount * p_rate;
  IF p_threshold IS NOT NULL AND p_cap IS NOT NULL AND p_amount >= p_threshold THEN
    v_gross := LEAST(v_gross, p_cap);
  END IF;
  RETURN QUERY SELECT
    v_gross,
    ROUND(v_gross * p_provider_share, 2),
    ROUND(v_gross * (1 - p_provider_share), 2);
END;
$$ LANGUAGE plpgsql;
