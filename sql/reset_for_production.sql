-- ============================================================
-- Chakka Saarthi — clear all TEST data before going live
-- Run ONCE in Supabase → SQL Editor → New query → Run.
-- ⚠ This cannot be undone. Take a backup first (admin app → Settings → Backup data).
--
-- KEEPS: your company (business name, short code), the admin account(s) and their MPIN,
--        all settings, security rules and the notification function.
-- DELETES: every trip, loading/unloading form, re-assignment, notification,
--          vehicle and driver.
-- ============================================================
BEGIN;

DELETE FROM notifications;
DELETE FROM analytics;
DELETE FROM trip_reassignments;
DELETE FROM unloading_status;
DELETE FROM loading_status;
DELETE FROM tickets;
DELETE FROM vehicles;
DELETE FROM users WHERE role = 'driver';

-- Everyone logs in again on their phone; old push addresses are forgotten
DELETE FROM app_sessions;
UPDATE users SET fcm_token = NULL;

-- New driver numbers continue after the admin (first new driver gets …002)
UPDATE users SET sequential_num = 1 WHERE role = 'admin' AND sequential_num > 1;

COMMIT;

-- Check: every count below should be 0, except "admins" (your admin accounts)
SELECT
  (SELECT COUNT(*) FROM tickets)                          AS trips,
  (SELECT COUNT(*) FROM vehicles)                         AS vehicles,
  (SELECT COUNT(*) FROM users WHERE role = 'driver')      AS drivers,
  (SELECT COUNT(*) FROM notifications)                    AS notifications,
  (SELECT COUNT(*) FROM users WHERE role = 'admin')       AS admins;
