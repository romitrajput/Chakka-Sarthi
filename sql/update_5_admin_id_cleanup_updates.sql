-- ============================================================
-- Chakka Saarthi — update 5
--   A. Dummy admin → real admin name, mobile and new ID (fill in 3 values in part A)
--   B. Delete test data created before 01-Nov-2026 (India time)
--   C. Storage folder for app updates (self-update)
--
-- ⚠ Part B cannot be undone. Take a backup first:
--    admin app → Settings → Backup data.
-- Run in Supabase → SQL Editor → New query → Run (after updates 1–4).
-- ============================================================
BEGIN;

-- ---------- A. Turn the dummy admin into a real, named admin ----------
-- ✏ FILL IN the 3 values below before pressing Run:
--    old ID  = the admin User ID you log in with today (e.g. MH01ADMT0001)
--    name    = the real admin's full name
--    mobile  = the real admin's 10-digit mobile number
-- New ID = SRLTRANSPORTAD + first 2 letters of first name + @1987
--          (e.g. Ajay → SRLTRANSPORTADAJ@1987). The MPIN stays the same.
DO $$
DECLARE
  v_old    TEXT := 'MH01ADMT0001';      -- ✏ old admin ID
  v_name   TEXT := 'WRITE ADMIN NAME';  -- ✏ real full name
  v_mobile TEXT := '0000000000';        -- ✏ real mobile
  v_old_name TEXT;
  v_first  TEXT;
  v_new    TEXT;
BEGIN
  IF v_name = 'WRITE ADMIN NAME' OR v_mobile = '0000000000' OR v_mobile !~ '^[0-9]{10}$' THEN
    RAISE EXCEPTION 'Fill in the admin name and 10-digit mobile at the top of part A first';
  END IF;
  SELECT full_name INTO v_old_name FROM users WHERE UPPER(user_id) = UPPER(v_old) AND role = 'admin';
  IF NOT FOUND THEN
    IF EXISTS (SELECT 1 FROM users WHERE role = 'admin' AND user_id LIKE 'SRLTRANSPORTAD%@%' AND mobile = v_mobile) THEN
      RAISE NOTICE 'Admin already updated earlier';
      RETURN;
    END IF;
    RAISE EXCEPTION 'No admin with ID % - check the old ID', v_old;
  END IF;
  SELECT user_id INTO v_old FROM users WHERE UPPER(user_id) = UPPER(v_old);
  IF EXISTS (SELECT 1 FROM users WHERE mobile = v_mobile AND user_id <> v_old) THEN
    RAISE EXCEPTION 'Mobile % is already used by another user', v_mobile;
  END IF;

  v_first := RPAD(LEFT(REGEXP_REPLACE(UPPER(SPLIT_PART(TRIM(v_name), ' ', 1)), '[^A-Z]', '', 'g'), 2), 2, 'X');
  v_new := 'SRLTRANSPORTAD' || v_first || '@1987';
  IF EXISTS (SELECT 1 FROM users WHERE UPPER(user_id) = UPPER(v_new)) THEN
    RAISE EXCEPTION 'Admin ID % already exists', v_new;
  END IF;

  UPDATE users SET user_id = v_new, full_name = TRIM(v_name), mobile = v_mobile WHERE user_id = v_old;
  -- Trips this login created now show the real name under "Assigned By"
  UPDATE tickets SET created_by = TRIM(v_name)
    WHERE created_by_user_id = v_old OR (created_by_user_id IS NULL AND created_by = v_old_name);
  UPDATE tickets            SET created_by_user_id = v_new WHERE created_by_user_id = v_old;
  UPDATE notifications      SET target_user_id     = v_new WHERE target_user_id     = v_old;
  UPDATE trip_reassignments SET reassigned_by      = v_new WHERE reassigned_by      = v_old;
  UPDATE analytics          SET user_id            = v_new WHERE user_id            = v_old;
  UPDATE app_sessions       SET user_id            = v_new WHERE user_id            = v_old;
  RAISE NOTICE 'Admin % is now % (%)', v_old, v_new, v_name;
END $$;

-- ---------- B. Test data before 01-Nov-2026 ----------
CREATE TEMP TABLE old_trips ON COMMIT DROP AS
  SELECT ticket_id FROM tickets WHERE created_at < TIMESTAMPTZ '2026-11-01 00:00:00+05:30';

DELETE FROM loading_status     WHERE ticket_id IN (SELECT ticket_id FROM old_trips);
DELETE FROM unloading_status   WHERE ticket_id IN (SELECT ticket_id FROM old_trips);
DELETE FROM trip_reassignments WHERE ticket_id IN (SELECT ticket_id FROM old_trips);
DELETE FROM notifications      WHERE ticket_id IN (SELECT ticket_id FROM old_trips)
                                  OR created_at < TIMESTAMPTZ '2026-11-01 00:00:00+05:30';
DELETE FROM analytics          WHERE ticket_id IN (SELECT ticket_id FROM old_trips)
                                  OR created_at < TIMESTAMPTZ '2026-11-01 00:00:00+05:30';
DELETE FROM tickets            WHERE ticket_id IN (SELECT ticket_id FROM old_trips);

-- Vehicles left "in transit" by a deleted test trip become available again
UPDATE vehicles v SET status = 'available'
WHERE v.status = 'in_transit'
  AND NOT EXISTS (SELECT 1 FROM tickets t
                  WHERE t.vehicle_id = v.id::text AND t.status IN ('assigned', 'in_transit'));

-- ---------- C. Public folder that holds the latest app (APK) ----------
INSERT INTO storage.buckets (id, name, public)
VALUES ('app-releases', 'app-releases', true)
ON CONFLICT (id) DO UPDATE SET public = true;

COMMIT;

-- ---------- Check ----------
-- 1) Admin ID and what is left
SELECT
  (SELECT string_agg(user_id || ' - ' || full_name, ', ') FROM users WHERE role = 'admin')        AS admins,
  (SELECT COUNT(*) FROM tickets WHERE created_at < TIMESTAMPTZ '2026-11-01 00:00:00+05:30')       AS trips_before_1_nov,
  (SELECT COUNT(*) FROM tickets)                                                                   AS trips_left;

-- 2) Drivers and vehicles were NOT deleted. These were added before 01-Nov-2026 —
--    if any of them are test entries, delete them in the app (Manage Drivers / Manage Vehicles).
SELECT 'Driver' AS type, user_id AS id, full_name AS name, created_at::date AS added_on
  FROM users WHERE role = 'driver' AND created_at < TIMESTAMPTZ '2026-11-01 00:00:00+05:30'
UNION ALL
SELECT 'Vehicle', vehicle_number, status, created_at::date
  FROM vehicles WHERE created_at < TIMESTAMPTZ '2026-11-01 00:00:00+05:30'
ORDER BY 1, 4;
