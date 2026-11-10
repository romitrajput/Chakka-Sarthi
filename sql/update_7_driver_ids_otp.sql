-- ============================================================
-- Chakka Saarthi — update 7
--   1. Driver IDs MTDR… become SRLDR…  (e.g. MTDRMANOJ002 → SRLDRMANOJ002)
--   2. Delete the test trips created on 01-Nov-2026 (India time)
--   3. Admin email + table for "Forgot Login PIN" email codes
--   4. Login error messages say "Login PIN" instead of "MPIN"
--
-- ⚠ Part 2 cannot be undone. Take a backup first: admin app → Settings → Backup data.
-- Run in Supabase → SQL Editor → New query → Run (after updates 1–6). Safe to run again.
-- ============================================================
BEGIN;

-- ---------- 1. Driver IDs ----------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM users a JOIN users b ON b.user_id = 'SRLDR' || SUBSTRING(a.user_id FROM 5)
             WHERE a.user_id LIKE 'MTDR%') THEN
    RAISE EXCEPTION 'Some SRLDR IDs already exist with the same name and number - nothing was changed. Tell Claude.';
  END IF;
END $$;

CREATE TEMP TABLE id_rename ON COMMIT DROP AS
  SELECT user_id AS old_id, 'SRLDR' || SUBSTRING(user_id FROM 5) AS new_id
  FROM users WHERE role = 'driver' AND user_id LIKE 'MTDR%';

UPDATE users              x SET user_id            = r.new_id FROM id_rename r WHERE x.user_id            = r.old_id;
UPDATE tickets            x SET driver_user_id     = r.new_id FROM id_rename r WHERE x.driver_user_id     = r.old_id;
UPDATE tickets            x SET created_by_user_id = r.new_id FROM id_rename r WHERE x.created_by_user_id = r.old_id;
UPDATE tickets            x SET reassigned_from    = r.new_id FROM id_rename r WHERE x.reassigned_from    = r.old_id;
UPDATE unloading_status   x SET unloaded_by        = r.new_id FROM id_rename r WHERE x.unloaded_by        = r.old_id;
UPDATE trip_reassignments x SET old_driver_user_id = r.new_id FROM id_rename r WHERE x.old_driver_user_id = r.old_id;
UPDATE trip_reassignments x SET new_driver_user_id = r.new_id FROM id_rename r WHERE x.new_driver_user_id = r.old_id;
UPDATE trip_reassignments x SET reassigned_by      = r.new_id FROM id_rename r WHERE x.reassigned_by      = r.old_id;
UPDATE notifications      x SET target_user_id     = r.new_id FROM id_rename r WHERE x.target_user_id     = r.old_id;
UPDATE analytics          x SET user_id            = r.new_id FROM id_rename r WHERE x.user_id            = r.old_id;
UPDATE app_sessions       x SET user_id            = r.new_id FROM id_rename r WHERE x.user_id            = r.old_id;

-- ---------- 2. Test trips of 01-Nov-2026 ----------
CREATE TEMP TABLE nov1_trips ON COMMIT DROP AS
  SELECT ticket_id FROM tickets
  WHERE created_at >= TIMESTAMPTZ '2026-11-01 00:00:00+05:30'
    AND created_at <  TIMESTAMPTZ '2026-11-02 00:00:00+05:30';

DELETE FROM loading_status     WHERE ticket_id IN (SELECT ticket_id FROM nov1_trips);
DELETE FROM unloading_status   WHERE ticket_id IN (SELECT ticket_id FROM nov1_trips);
DELETE FROM trip_reassignments WHERE ticket_id IN (SELECT ticket_id FROM nov1_trips);
DELETE FROM notifications      WHERE ticket_id IN (SELECT ticket_id FROM nov1_trips);
DELETE FROM analytics          WHERE ticket_id IN (SELECT ticket_id FROM nov1_trips);
DELETE FROM tickets            WHERE ticket_id IN (SELECT ticket_id FROM nov1_trips);

UPDATE vehicles v SET status = 'available'
WHERE v.status = 'in_transit'
  AND NOT EXISTS (SELECT 1 FROM tickets t
                  WHERE t.vehicle_id = v.id::text AND t.status IN ('assigned', 'in_transit'));

-- ---------- 3. Forgot Login PIN by email code ----------
ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT;
GRANT SELECT (email) ON users TO authenticated;

-- Codes live here; phones can never read this table (only the pin-reset function can)
CREATE TABLE IF NOT EXISTS pin_reset_codes (
  user_id    TEXT PRIMARY KEY,
  code_hash  TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  attempts   INT NOT NULL DEFAULT 0,
  sent_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE pin_reset_codes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON pin_reset_codes FROM anon, authenticated;

-- ---------- 4. Login messages say "Login PIN" ----------
CREATE OR REPLACE FUNCTION app_login(p_user_id TEXT, p_mobile TEXT DEFAULT NULL, p_mpin_hash TEXT DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  u users;
  v_id TEXT := TRIM(COALESCE(p_user_id, ''));
  v_matches INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Session missing. Please try again.';
  END IF;

  IF p_mpin_hash IS NOT NULL THEN
    SELECT COUNT(*) INTO v_matches FROM users
      WHERE is_active AND NOT is_first_login AND mpin_hash = p_mpin_hash
        AND (UPPER(user_id) = UPPER(v_id) OR mobile = v_id);
    IF v_matches > 1 THEN
      RAISE EXCEPTION 'This mobile number is used by more than one account. Please log in with your User ID.';
    END IF;
    SELECT * INTO u FROM users
      WHERE is_active AND NOT is_first_login AND mpin_hash = p_mpin_hash
        AND (UPPER(user_id) = UPPER(v_id) OR mobile = v_id)
      LIMIT 1;
    IF NOT FOUND THEN
      IF EXISTS (SELECT 1 FROM users WHERE is_active AND is_first_login
                 AND (UPPER(user_id) = UPPER(v_id) OR mobile = v_id)) THEN
        RAISE EXCEPTION 'Login PIN not set yet. Tap "First time? Set up your Login PIN" and log in with your User ID and mobile number.';
      END IF;
      RAISE EXCEPTION 'Wrong User ID / mobile number or Login PIN';
    END IF;
  ELSE
    SELECT * INTO u FROM users WHERE UPPER(user_id) = UPPER(v_id) AND is_active;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid User ID';
    END IF;
    IF u.mobile IS DISTINCT FROM TRIM(COALESCE(p_mobile, '')) THEN
      RAISE EXCEPTION 'Invalid User ID or mobile number';
    END IF;
    IF NOT u.is_first_login THEN
      RAISE EXCEPTION 'Login PIN already set. Please log in with your Login PIN.';
    END IF;
  END IF;

  -- One phone per driver: block if this driver is logged in on another phone
  IF u.role = 'driver' AND EXISTS (
       SELECT 1 FROM app_sessions s WHERE s.user_id = u.user_id AND s.auth_uid <> auth.uid()) THEN
    RAISE EXCEPTION 'You are already logged in on another phone. Log out there first, or ask your admin to log you out from all devices.';
  END IF;

  -- This phone now belongs to this user only
  DELETE FROM app_sessions WHERE auth_uid = auth.uid() AND user_id <> u.user_id;
  INSERT INTO app_sessions (auth_uid, user_id, company_code)
  VALUES (auth.uid(), u.user_id, u.company_code)
  ON CONFLICT (auth_uid) DO UPDATE
    SET user_id = EXCLUDED.user_id, company_code = EXCLUDED.company_code, created_at = NOW();

  RETURN (to_jsonb(u) - 'mpin_hash' - 'fcm_token')::json;
END $$;
REVOKE ALL ON FUNCTION app_login(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION app_login(TEXT, TEXT, TEXT) TO authenticated;

COMMIT;

-- ---------- Check ----------
SELECT
  (SELECT COUNT(*) FROM users WHERE user_id LIKE 'MTDR%')                       AS old_mt_driver_ids_left,
  (SELECT string_agg(user_id, ', ') FROM users WHERE role = 'driver')           AS driver_ids,
  (SELECT COUNT(*) FROM tickets
     WHERE created_at >= TIMESTAMPTZ '2026-11-01 00:00:00+05:30'
       AND created_at <  TIMESTAMPTZ '2026-11-02 00:00:00+05:30')               AS nov1_trips_left;
