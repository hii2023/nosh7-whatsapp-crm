-- ============================================================
-- NOSH7 WhatsApp CRM — Supabase Database Schema
-- Run this in your Supabase SQL editor (ap-south-1 region)
-- ============================================================

-- 1. CUSTOMERS TABLE
CREATE TABLE customers (
  id                    TEXT PRIMARY KEY,             -- e.g. C001
  name                  TEXT NOT NULL,
  phone                 TEXT NOT NULL UNIQUE,          -- WhatsApp number with country code, e.g. 919876543210
  plan_type             TEXT NOT NULL CHECK (plan_type IN ('Daily Lite','Weekly Standard','Monthly Premium')),
  start_date            DATE NOT NULL,
  end_date              DATE NOT NULL,
  payment_status        TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('paid','unpaid','failed')),
  subscription_status   TEXT NOT NULL DEFAULT 'active' CHECK (subscription_status IN ('active','paused','expired')),
  preferences           TEXT CHECK (preferences IN ('Vegan','Jain','Keto','High-Protein')),
  delivery_address      TEXT,
  delivery_zone         TEXT CHECK (delivery_zone IN ('Zone A','Zone B','Zone C','Zone D')),
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- 2. CUSTOMER CLASSIFICATION TABLE (refreshed daily at 6 AM IST)
CREATE TABLE customer_classification (
  id                    SERIAL PRIMARY KEY,
  customer_id           TEXT REFERENCES customers(id) ON DELETE CASCADE,
  classification_bucket TEXT NOT NULL,
  -- Buckets: Lead | New Customer | Active | Renewal Due - 3 Days | Renewal Due - 2 Days |
  --          Renewal Due - 1 Day | Expired | Dormant | Payment Pending | Engaged | At-Risk
  classified_at         TIMESTAMPTZ DEFAULT NOW(),
  notes                 TEXT
);

-- 3. MESSAGE LOG TABLE
CREATE TABLE message_log (
  id                    SERIAL PRIMARY KEY,
  customer_id           TEXT REFERENCES customers(id) ON DELETE SET NULL,
  flow_name             TEXT NOT NULL,
  template_name         TEXT,
  message_sent          TEXT NOT NULL,
  sent_at               TIMESTAMPTZ DEFAULT NOW(),
  delivered             BOOLEAN DEFAULT FALSE,
  read                  BOOLEAN DEFAULT FALSE,
  replied               BOOLEAN DEFAULT FALSE,
  replied_at            TIMESTAMPTZ
);

-- 4. FEEDBACK TABLE
CREATE TABLE feedback (
  id                    SERIAL PRIMARY KEY,
  customer_id           TEXT REFERENCES customers(id) ON DELETE SET NULL,
  rating                INTEGER CHECK (rating BETWEEN 1 AND 5),
  comment               TEXT,
  received_at           TIMESTAMPTZ DEFAULT NOW(),
  escalated             BOOLEAN DEFAULT FALSE,
  escalated_at          TIMESTAMPTZ,
  google_review_sent    BOOLEAN DEFAULT FALSE
);

-- 5. SKIP LOG TABLE
CREATE TABLE skip_log (
  id                    SERIAL PRIMARY KEY,
  customer_id           TEXT REFERENCES customers(id) ON DELETE CASCADE,
  skip_date             DATE NOT NULL,
  reason                TEXT,
  logged_at             TIMESTAMPTZ DEFAULT NOW()
);

-- 6. WHATSAPP TEMPLATES TABLE
CREATE TABLE wa_templates (
  id                    SERIAL PRIMARY KEY,
  name                  TEXT NOT NULL UNIQUE,
  type                  TEXT CHECK (type IN ('HSM','Conversational')),
  flow_name             TEXT,
  body                  TEXT NOT NULL,
  approval_status       TEXT DEFAULT 'pending' CHECK (approval_status IN ('pending','approved','rejected')),
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX idx_customers_phone         ON customers(phone);
CREATE INDEX idx_customers_status        ON customers(subscription_status);
CREATE INDEX idx_customers_end_date      ON customers(end_date);
CREATE INDEX idx_customers_payment       ON customers(payment_status);
CREATE INDEX idx_classification_customer ON customer_classification(customer_id);
CREATE INDEX idx_classification_bucket   ON customer_classification(classification_bucket);
CREATE INDEX idx_message_log_customer    ON message_log(customer_id);
CREATE INDEX idx_message_log_sent_at     ON message_log(sent_at);
CREATE INDEX idx_feedback_customer       ON feedback(customer_id);

-- ============================================================
-- AUTO-UPDATE updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- DAILY CLASSIFICATION FUNCTION (call via n8n cron at 6AM IST)
-- ============================================================
CREATE OR REPLACE FUNCTION run_daily_classification()
RETURNS void AS $$
DECLARE today DATE := CURRENT_DATE;
BEGIN
  DELETE FROM customer_classification WHERE classified_at::DATE = today;
  INSERT INTO customer_classification (customer_id, classification_bucket)
  SELECT id,
    CASE
      WHEN subscription_status = 'active' AND (today - start_date) <= 7  THEN 'New Customer'
      WHEN subscription_status = 'active' AND payment_status = 'failed'   THEN 'Payment Pending'
      WHEN subscription_status = 'active' AND payment_status = 'unpaid'   THEN 'Payment Pending'
      WHEN subscription_status = 'active' AND end_date = today + 3        THEN 'Renewal Due - 3 Days'
      WHEN subscription_status = 'active' AND end_date = today + 2        THEN 'Renewal Due - 2 Days'
      WHEN subscription_status = 'active' AND end_date = today + 1        THEN 'Renewal Due - 1 Day'
      WHEN subscription_status = 'active' AND end_date > today + 3        THEN 'Active'
      WHEN subscription_status = 'expired' AND (today - end_date) > 30    THEN 'Dormant'
      WHEN subscription_status = 'expired'                                  THEN 'Expired'
      ELSE 'Lead'
    END
  FROM customers;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- SAMPLE DATA (20 customers — matches admin dashboard)
-- ============================================================
INSERT INTO customers VALUES
('C001','Priya Sharma','919876543210','Weekly Standard','2026-03-01','2026-04-01','paid','active','Vegan','Flat 12B, Bandra West, Mumbai','Zone A',NOW(),NOW()),
('C002','Rahul Mehta','919823456789','Monthly Premium','2026-02-15','2026-03-15','unpaid','expired','High-Protein','302, Andheri East, Mumbai','Zone B',NOW(),NOW()),
('C003','Ananya Patel','919712345678','Daily Lite','2026-03-20','2026-04-20','paid','active','Jain','Villa 5, Juhu, Mumbai','Zone A',NOW(),NOW()),
('C004','Karan Kapoor','919634567890','Weekly Standard','2026-03-22','2026-03-27','paid','active','Keto','45, Powai, Mumbai','Zone C',NOW(),NOW()),
('C005','Sneha Joshi','919556789012','Monthly Premium','2026-01-10','2026-02-10','paid','expired','Vegan','8, Goregaon West, Mumbai','Zone B',NOW(),NOW()),
('C006','Arjun Nair','919478901234','Daily Lite','2026-03-24','2026-04-24','paid','active','High-Protein','12, Malad West, Mumbai','Zone B',NOW(),NOW()),
('C007','Meera Iyer','919390123456','Weekly Standard','2026-03-01','2026-03-25','failed','active','Vegan','3, Santacruz, Mumbai','Zone A',NOW(),NOW()),
('C008','Dev Bose','919212345678','Monthly Premium','2026-03-24','2026-04-24','paid','active','Keto','78, Vikhroli, Mumbai','Zone C',NOW(),NOW()),
('C009','Riya Gupta','919134567890','Daily Lite','2026-02-01','2026-02-28','paid','expired','Jain','Apt 9, Chembur, Mumbai','Zone C',NOW(),NOW()),
('C010','Amit Shah','919056789012','Weekly Standard','2026-03-10','2026-03-27','paid','active','High-Protein','22, Thane West','Zone D',NOW(),NOW()),
('C011','Kavya Reddy','918978901234','Monthly Premium','2026-03-24','2026-04-24','paid','active','Vegan','5, Navi Mumbai','Zone D',NOW(),NOW()),
('C012','Rohan Verma','918890123456','Daily Lite','2026-03-01','2026-03-15','paid','expired','Keto','101, Kurla, Mumbai','Zone B',NOW(),NOW()),
('C013','Nisha Kulkarni','918712345678','Weekly Standard','2026-03-24','2026-04-24','paid','active','Vegan','14, Dadar, Mumbai','Zone A',NOW(),NOW()),
('C014','Vikram Singh','918634567890','Monthly Premium','2026-03-05','2026-04-05','paid','active','High-Protein','67, Borivali, Mumbai','Zone B',NOW(),NOW()),
('C015','Pooja Desai','918556789012','Daily Lite','2026-01-01','2026-01-31','paid','expired','Jain','2, Vasai, Mumbai','Zone D',NOW(),NOW()),
('C016','Suresh Kumar','918478901234','Weekly Standard','2026-03-24','2026-03-25','paid','active','Keto','9, Kandivali, Mumbai','Zone B',NOW(),NOW()),
('C017','Lakshmi Nair','918390123456','Monthly Premium','2026-03-20','2026-04-20','paid','active','Vegan','33, Matunga, Mumbai','Zone A',NOW(),NOW()),
('C018','Kartik Patel','918212345678','Daily Lite','2026-03-24','2026-04-24','paid','active','High-Protein','55, Ghatkopar, Mumbai','Zone C',NOW(),NOW()),
('C019','Divya Sharma','918134567890','Weekly Standard','2026-03-24','2026-03-26','unpaid','active','Jain','7, Mulund, Mumbai','Zone C',NOW(),NOW()),
('C020','Nikhil Joshi','918056789012','Monthly Premium','2026-03-21','2026-04-21','paid','active','Keto','88, Bhandup, Mumbai','Zone C',NOW(),NOW());
