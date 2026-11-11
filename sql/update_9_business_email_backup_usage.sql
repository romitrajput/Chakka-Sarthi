-- ============================================================
-- Chakka Saarthi — update 9
--   1. Business email (Settings → under Business name). Used for Forgot Login PIN codes and backups.
--   2. Weekly automatic backup by email (zip), only when there is new data.
--   3. Private usage log: which admin features are used, and when (no names, no IDs).
--
-- ✏ FILL IN ONE VALUE in part 2 before running: your Supabase project URL
--    (Supabase → Project Settings → Data API → Project URL, e.g. https://abcdxyz.supabase.co)
-- Run in Supabase → SQL Editor → New query → Run (after updates 1–7). Safe to run again.
-- ============================================================

-- ---------- 1. Business email ----------
ALTER TABLE companies ADD COLUMN IF NOT EXISTS business_email   TEXT;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS last_backup_at   TIMESTAMPTZ;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS last_backup_hash TEXT;
GRANT SELECT (business_email, last_backup_at) ON companies TO authenticated;

-- ---------- 2. Weekly backup by email ----------
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
REVOKE ALL ON private.settings FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;
GRANT SELECT ON private.settings TO service_role;

-- Secret the weekly timer shows to the backup function (made once, never shown in the app)
INSERT INTO private.settings (key, value)
VALUES ('backup_cron_secret', replace(gen_random_uuid()::TEXT || gen_random_uuid()::TEXT, '-', ''))
ON CONFLICT (key) DO NOTHING;

-- The backup function reads this through a server-only check
CREATE OR REPLACE FUNCTION public.cs_check_backup_secret(p_secret TEXT) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM private.settings WHERE key = 'backup_cron_secret' AND value = p_secret)
$$;
REVOKE ALL ON FUNCTION public.cs_check_backup_secret(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cs_check_backup_secret(TEXT) TO service_role;

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

DO $$
DECLARE
  v_url TEXT := 'https://YOUR-PROJECT.supabase.co';   -- ✏ your Project URL
  v_secret TEXT;
BEGIN
  IF v_url LIKE '%YOUR-PROJECT%' THEN
    RAISE EXCEPTION 'Fill in your Supabase Project URL in part 2 first';
  END IF;
  SELECT value INTO v_secret FROM private.settings WHERE key = 'backup_cron_secret';
  -- Every Sunday 03:00 India time (Saturday 21:30 UTC)
  PERFORM cron.schedule(
    'chakka-weekly-backup',
    '30 21 * * 6',
    format($cmd$SELECT net.http_post(url := %L, body := '{"mode":"weekly"}'::jsonb,
             headers := jsonb_build_object('Content-Type', 'application/json', 'x-backup-secret', %L),
             timeout_milliseconds := 120000)$cmd$,
           rtrim(v_url, '/') || '/functions/v1/email-backup', v_secret)
  );
END $$;

-- ---------- 3. Private usage log ----------
CREATE SCHEMA IF NOT EXISTS usage;
REVOKE ALL ON SCHEMA usage FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS usage.events (
  id           BIGSERIAL PRIMARY KEY,
  at           TIMESTAMPTZ NOT NULL,
  company_code TEXT,
  role         TEXT,
  event        TEXT NOT NULL,        -- e.g. screen_view, trip_created, report_pdf
  screen       TEXT,                 -- e.g. /admin/trips
  detail       TEXT,                 -- small extra info, never names or phone numbers
  platform     TEXT,                 -- android / web
  app_version  TEXT
);
CREATE INDEX IF NOT EXISTS usage_events_at ON usage.events (at);
CREATE INDEX IF NOT EXISTS usage_events_event ON usage.events (event);
REVOKE ALL ON usage.events FROM PUBLIC, anon, authenticated;

-- The app can only ADD events (max 50 per call); nobody can read them from the app
CREATE OR REPLACE FUNCTION public.log_usage(p_events JSONB) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_role TEXT;
  v_company TEXT := my_company();
BEGIN
  IF v_company IS NULL OR jsonb_typeof(p_events) <> 'array' THEN RETURN; END IF;
  SELECT role INTO v_role FROM users WHERE user_id = my_user_id();
  INSERT INTO usage.events (at, company_code, role, event, screen, detail, platform, app_version)
  SELECT LEAST(COALESCE((e->>'at')::TIMESTAMPTZ, NOW()), NOW()),
         v_company, v_role,
         LEFT(e->>'event', 60), LEFT(e->>'screen', 80), LEFT(e->>'detail', 120),
         LEFT(e->>'platform', 20), LEFT(e->>'app_version', 20)
  FROM (SELECT value AS e FROM jsonb_array_elements(p_events) LIMIT 50) x
  WHERE COALESCE(e->>'event', '') <> '';
END $$;
REVOKE ALL ON FUNCTION public.log_usage(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_usage(JSONB) TO authenticated;

-- Keep one year of usage history
SELECT cron.schedule('chakka-usage-cleanup', '0 22 1 * *',
  $$DELETE FROM usage.events WHERE at < NOW() - INTERVAL '365 days'$$);

-- ============================================================
-- Check
SELECT jobname, schedule FROM cron.job WHERE jobname LIKE 'chakka-%';
