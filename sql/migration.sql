-- ============================================================
-- MIGRATION: Sanjay Roadlines Fleet Management App
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. ADD DRIVER DOCUMENT COLUMNS TO USERS TABLE
-- ============================================================
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS driving_license_url TEXT,
  ADD COLUMN IF NOT EXISTS aadhaar_card_url TEXT;

-- 2. ADD CHALLAN/DOCUMENT URL + REPORTING DATE TO TICKETS TABLE
-- ============================================================
ALTER TABLE tickets
  ADD COLUMN IF NOT EXISTS reporting_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS challan_urls JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS reassigned_from TEXT,
  ADD COLUMN IF NOT EXISTS reassignment_count INT DEFAULT 0;

-- 3. ADD RETENTION PERIOD COLUMN
-- ============================================================
ALTER TABLE tickets
  ADD COLUMN IF NOT EXISTS retention_days INT;

-- 4. ADD MAINTENANCE COLUMNS TO VEHICLES TABLE
-- ============================================================
ALTER TABLE vehicles
  ADD COLUMN IF NOT EXISTS maintenance_reason TEXT,
  ADD COLUMN IF NOT EXISTS maintenance_from TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS maintenance_expected_return TIMESTAMPTZ;

-- 5. WEIGHT COLUMNS: MT → Kgs (SKIP IF ALREADY MIGRATED)
-- Only runs if the old _mt columns still exist
-- ============================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'loading_status' AND column_name = 'loading_weight_mt'
  ) THEN
    ALTER TABLE loading_status ALTER COLUMN loading_weight_mt TYPE NUMERIC(12,2);
    ALTER TABLE unloading_status ALTER COLUMN loading_weight_mt TYPE NUMERIC(12,2);
    ALTER TABLE unloading_status ALTER COLUMN shortage_mt TYPE NUMERIC(12,2);

    UPDATE loading_status SET loading_weight_mt = loading_weight_mt * 1000 WHERE loading_weight_mt IS NOT NULL;
    UPDATE unloading_status SET loading_weight_mt = loading_weight_mt * 1000 WHERE loading_weight_mt IS NOT NULL;
    UPDATE unloading_status SET shortage_mt = shortage_mt * 1000 WHERE shortage_mt IS NOT NULL;

    ALTER TABLE loading_status RENAME COLUMN loading_weight_mt TO loading_weight_kgs;
    ALTER TABLE unloading_status RENAME COLUMN loading_weight_mt TO loading_weight_kgs;
    ALTER TABLE unloading_status RENAME COLUMN shortage_mt TO shortage_kgs;
  END IF;
END $$;

-- 6. CREATE TRIPS REASSIGNMENTS AUDIT TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS trip_reassignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ticket_id TEXT NOT NULL,
  old_driver_user_id TEXT NOT NULL,
  new_driver_user_id TEXT NOT NULL,
  reassigned_by TEXT NOT NULL,
  reassigned_at TIMESTAMPTZ DEFAULT NOW(),
  reason TEXT
);

-- Enable RLS
ALTER TABLE trip_reassignments ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Admins can view reassignments"
  ON trip_reassignments FOR SELECT
  USING (true);

CREATE POLICY "Admins can create reassignments"
  ON trip_reassignments FOR INSERT
  WITH CHECK (true);

-- ============================================================
-- END OF MIGRATION
-- ============================================================
