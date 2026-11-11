-- ============================================================
-- Chakka Saarthi — usage reports (admins only, no personal data)
-- Paste ONE query at a time into Supabase → SQL Editor → Run.
-- Times are shown in India time.
-- ============================================================

-- 1. Most used features in the last 30 days
SELECT event, COUNT(*) AS times
FROM usage.events
WHERE at > NOW() - INTERVAL '30 days' AND event <> 'screen_view'
GROUP BY event ORDER BY times DESC;

-- 2. Most opened screens in the last 30 days
SELECT screen, COUNT(*) AS opens
FROM usage.events
WHERE at > NOW() - INTERVAL '30 days' AND event = 'screen_view'
GROUP BY screen ORDER BY opens DESC;

-- 3. Busiest hours of the day (India time)
SELECT EXTRACT(HOUR FROM at AT TIME ZONE 'Asia/Kolkata')::INT AS hour, COUNT(*) AS actions
FROM usage.events
WHERE at > NOW() - INTERVAL '30 days'
GROUP BY hour ORDER BY hour;

-- 4. Busiest days of the week
SELECT TO_CHAR(at AT TIME ZONE 'Asia/Kolkata', 'Dy') AS day,
       EXTRACT(ISODOW FROM at AT TIME ZONE 'Asia/Kolkata')::INT AS day_no,
       COUNT(*) AS actions
FROM usage.events
WHERE at > NOW() - INTERVAL '30 days'
GROUP BY day, day_no ORDER BY day_no;

-- 5. Phone app vs website
SELECT platform, COUNT(*) AS actions, COUNT(*) FILTER (WHERE event = 'session_start') AS sessions
FROM usage.events
WHERE at > NOW() - INTERVAL '30 days'
GROUP BY platform;

-- 6. Week by week: trips created, reports, backups
SELECT DATE_TRUNC('week', at AT TIME ZONE 'Asia/Kolkata')::DATE AS week,
       COUNT(*) FILTER (WHERE event = 'trip_created')    AS trips_created,
       COUNT(*) FILTER (WHERE event = 'trip_reassigned') AS reassigned,
       COUNT(*) FILTER (WHERE event IN ('report_pdf', 'report_excel', 'trip_pdf')) AS reports,
       COUNT(*) FILTER (WHERE event LIKE 'backup%')      AS backups,
       COUNT(*) FILTER (WHERE event = 'session_start')   AS sessions
FROM usage.events
GROUP BY week ORDER BY week DESC;

-- 7. Which app versions are in use
SELECT app_version, platform, MAX(at AT TIME ZONE 'Asia/Kolkata') AS last_seen, COUNT(*) AS actions
FROM usage.events
GROUP BY app_version, platform ORDER BY last_seen DESC;
