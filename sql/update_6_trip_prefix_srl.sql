-- ============================================================
-- Chakka Saarthi — update 6: Trip IDs start with SRL (Sanjay Roadlines)
--   1. Short code of the business becomes SRL → every NEW trip is "SRL DDMMYYYY-001"
--   2. Existing trips "MT ..." are renamed to "SRL ..." everywhere (forms, reports,
--      re-assignments, notifications).
-- Run in Supabase → SQL Editor → New query → Run. Safe to run again.
-- ============================================================
BEGIN;

UPDATE companies SET short_name = 'SRL';

-- Stop if a renamed ID would clash with a trip that already starts with SRL
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM tickets a JOIN tickets b
             ON b.ticket_id = 'SRL' || SUBSTRING(a.ticket_id FROM 3)
             WHERE a.ticket_id LIKE 'MT %') THEN
    RAISE EXCEPTION 'Some SRL trip IDs already exist with the same number - nothing was changed. Tell Claude.';
  END IF;
END $$;

CREATE TEMP TABLE trip_rename ON COMMIT DROP AS
  SELECT ticket_id AS old_id, 'SRL' || SUBSTRING(ticket_id FROM 3) AS new_id
  FROM tickets WHERE ticket_id LIKE 'MT %';

UPDATE loading_status     x SET ticket_id = r.new_id FROM trip_rename r WHERE x.ticket_id = r.old_id;
UPDATE unloading_status   x SET ticket_id = r.new_id FROM trip_rename r WHERE x.ticket_id = r.old_id;
UPDATE trip_reassignments x SET ticket_id = r.new_id FROM trip_rename r WHERE x.ticket_id = r.old_id;
UPDATE analytics          x SET ticket_id = r.new_id FROM trip_rename r WHERE x.ticket_id = r.old_id;
UPDATE notifications      x SET ticket_id = r.new_id,
                                title   = REPLACE(x.title,   r.old_id, r.new_id),
                                message = REPLACE(x.message, r.old_id, r.new_id)
  FROM trip_rename r WHERE x.ticket_id = r.old_id;
-- Notifications that mention the trip only in their text
UPDATE notifications x SET title   = REPLACE(x.title,   r.old_id, r.new_id),
                           message = REPLACE(x.message, r.old_id, r.new_id)
  FROM trip_rename r WHERE x.message LIKE '%' || r.old_id || '%' OR x.title LIKE '%' || r.old_id || '%';
UPDATE tickets            x SET ticket_id = r.new_id FROM trip_rename r WHERE x.ticket_id = r.old_id;

COMMIT;

-- Check: short code and trips
SELECT
  (SELECT string_agg(short_name, ', ') FROM companies)              AS short_code,
  (SELECT COUNT(*) FROM tickets WHERE ticket_id LIKE 'MT %')        AS mt_trips_left,
  (SELECT COUNT(*) FROM tickets WHERE ticket_id LIKE 'SRL %')       AS srl_trips;
