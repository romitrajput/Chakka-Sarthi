-- ============================================================
-- Chakka Saarthi — security lock-down + new features
-- Run ONCE in Supabase → SQL Editor → New query → Run.
-- Safe to run again. Run it BEFORE installing the new app build:
-- older app versions cannot log in once this is applied.
-- ============================================================

-- ---------- 1. New columns ----------
ALTER TABLE users ADD COLUMN IF NOT EXISTS license_expiry DATE;   -- driving licence expiry
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;        -- phone address for push notifications

-- ---------- 2. Which app user each signed-in phone belongs to ----------
CREATE TABLE IF NOT EXISTS app_sessions (
  auth_uid     UUID PRIMARY KEY,
  user_id      TEXT NOT NULL,
  company_code TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE app_sessions ENABLE ROW LEVEL SECURITY;  -- no policies: only the functions below touch it
REVOKE ALL ON app_sessions FROM anon, authenticated;

CREATE OR REPLACE FUNCTION my_company() RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT s.company_code FROM app_sessions s
  JOIN users u ON u.user_id = s.user_id AND u.is_active
  WHERE s.auth_uid = auth.uid()
$$;

CREATE OR REPLACE FUNCTION my_user_id() RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT s.user_id FROM app_sessions s
  JOIN users u ON u.user_id = s.user_id AND u.is_active
  WHERE s.auth_uid = auth.uid()
$$;

CREATE OR REPLACE FUNCTION is_admin() RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM app_sessions s JOIN users u ON u.user_id = s.user_id
    WHERE s.auth_uid = auth.uid() AND u.role = 'admin' AND u.is_active
  )
$$;

-- ---------- 3. Login: checked on the server, never by reading the users table ----------
-- Mobile login (first time) or MPIN login. Returns the user without the MPIN hash.
CREATE OR REPLACE FUNCTION app_login(p_user_id TEXT, p_mobile TEXT DEFAULT NULL, p_mpin_hash TEXT DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE u users;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Session missing. Please try again.';
  END IF;

  SELECT * INTO u FROM users WHERE user_id = TRIM(p_user_id) AND is_active;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid User ID';
  END IF;

  IF p_mpin_hash IS NOT NULL THEN
    IF u.is_first_login THEN
      RAISE EXCEPTION 'Please login with mobile number first to set your MPIN';
    END IF;
    IF u.mpin_hash IS DISTINCT FROM p_mpin_hash THEN
      RAISE EXCEPTION 'Invalid User ID or MPIN';
    END IF;
  ELSE
    IF u.mobile IS DISTINCT FROM TRIM(COALESCE(p_mobile, '')) THEN
      RAISE EXCEPTION 'Invalid User ID or mobile number';
    END IF;
    IF NOT u.is_first_login THEN
      RAISE EXCEPTION 'MPIN already set. Please login using your MPIN';
    END IF;
  END IF;

  INSERT INTO app_sessions (auth_uid, user_id, company_code)
  VALUES (auth.uid(), u.user_id, u.company_code)
  ON CONFLICT (auth_uid) DO UPDATE
    SET user_id = EXCLUDED.user_id, company_code = EXCLUDED.company_code, created_at = NOW();

  RETURN (to_jsonb(u) - 'mpin_hash' - 'fcm_token')::json;
END $$;

CREATE OR REPLACE FUNCTION app_logout() RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  DELETE FROM app_sessions WHERE auth_uid = auth.uid()
$$;

-- Admin "reset company data" code check (the code itself is never sent to phones)
CREATE OR REPLACE FUNCTION verify_reset_code(p_code TEXT) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT is_admin() AND EXISTS (
    SELECT 1 FROM companies
    WHERE company_code = my_company() AND reset_code IS NOT NULL AND reset_code <> '' AND reset_code = p_code
  )
$$;

-- Save this phone's push-notification address for the signed-in user
CREATE OR REPLACE FUNCTION save_fcm_token(p_token TEXT) RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE users SET fcm_token = NULLIF(p_token, '') WHERE user_id = my_user_id()
$$;

REVOKE ALL ON FUNCTION app_login(TEXT, TEXT, TEXT), app_logout(), verify_reset_code(TEXT), save_fcm_token(TEXT),
  my_company(), my_user_id(), is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION app_login(TEXT, TEXT, TEXT), app_logout(), verify_reset_code(TEXT), save_fcm_token(TEXT),
  my_company(), my_user_id(), is_admin() TO authenticated;

-- ---------- 4. Hide secrets: MPIN hashes, push tokens, reset code ----------
REVOKE SELECT ON users FROM anon, authenticated;
GRANT SELECT (id, user_id, full_name, mobile, role, company_code, is_first_login, is_active,
              sequential_num, created_at, driving_license_url, aadhaar_card_url, license_expiry)
  ON users TO authenticated;

REVOKE SELECT ON companies FROM anon, authenticated;
GRANT SELECT (id, company_code, company_name, short_name, state_code, created_at) ON companies TO authenticated;

-- Nothing at all for phones that are not logged in
REVOKE ALL ON companies, users, vehicles, tickets, loading_status, unloading_status,
              notifications, trip_reassignments, analytics FROM anon;

-- ---------- 5. Row rules: only your own company's data ----------
DO $$
DECLARE t TEXT; p RECORD;
BEGIN
  -- remove every old policy on these tables (including the old "anyone can do anything" one)
  FOR p IN SELECT tablename, policyname FROM pg_policies
           WHERE schemaname = 'public'
             AND tablename IN ('companies','users','vehicles','tickets','loading_status','unloading_status',
                               'notifications','trip_reassignments','analytics')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', p.policyname, p.tablename);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['companies','users','vehicles','tickets','loading_status','unloading_status',
                           'notifications','trip_reassignments','analytics']
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- companies: read own; only admins change it (business name)
CREATE POLICY cs_read   ON companies FOR SELECT TO authenticated USING (company_code = my_company());
CREATE POLICY cs_update ON companies FOR UPDATE TO authenticated USING (company_code = my_company() AND is_admin())
  WITH CHECK (company_code = my_company());

-- users: read own company; admins add/remove; admins or the person themself update (MPIN, push token)
CREATE POLICY cs_read   ON users FOR SELECT TO authenticated USING (company_code = my_company());
CREATE POLICY cs_insert ON users FOR INSERT TO authenticated WITH CHECK (company_code = my_company() AND is_admin());
CREATE POLICY cs_update ON users FOR UPDATE TO authenticated
  USING (company_code = my_company() AND (is_admin() OR user_id = my_user_id()))
  WITH CHECK (company_code = my_company());
CREATE POLICY cs_delete ON users FOR DELETE TO authenticated USING (company_code = my_company() AND is_admin());

-- vehicles: read/update own company (drivers free a vehicle at trip end); admins add/remove
CREATE POLICY cs_read   ON vehicles FOR SELECT TO authenticated USING (company_code = my_company());
CREATE POLICY cs_insert ON vehicles FOR INSERT TO authenticated WITH CHECK (company_code = my_company() AND is_admin());
CREATE POLICY cs_update ON vehicles FOR UPDATE TO authenticated USING (company_code = my_company())
  WITH CHECK (company_code = my_company());
CREATE POLICY cs_delete ON vehicles FOR DELETE TO authenticated USING (company_code = my_company() AND is_admin());

-- tickets (trips): read/update own company; admins create/delete
CREATE POLICY cs_read   ON tickets FOR SELECT TO authenticated USING (company_code = my_company());
CREATE POLICY cs_insert ON tickets FOR INSERT TO authenticated WITH CHECK (company_code = my_company() AND is_admin());
CREATE POLICY cs_update ON tickets FOR UPDATE TO authenticated USING (company_code = my_company())
  WITH CHECK (company_code = my_company());
CREATE POLICY cs_delete ON tickets FOR DELETE TO authenticated USING (company_code = my_company() AND is_admin());

-- loading / unloading forms: belong to a trip of your company
CREATE POLICY cs_all ON loading_status FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = loading_status.ticket_id AND t.company_code = my_company()))
  WITH CHECK (EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = loading_status.ticket_id AND t.company_code = my_company()));
CREATE POLICY cs_all ON unloading_status FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = unloading_status.ticket_id AND t.company_code = my_company()))
  WITH CHECK (EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = unloading_status.ticket_id AND t.company_code = my_company()));

-- re-assignment log: read own company's; admins write
CREATE POLICY cs_read ON trip_reassignments FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = trip_reassignments.ticket_id AND t.company_code = my_company()));
CREATE POLICY cs_write ON trip_reassignments FOR INSERT TO authenticated
  WITH CHECK (is_admin() AND EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = trip_reassignments.ticket_id AND t.company_code = my_company()));
CREATE POLICY cs_delete ON trip_reassignments FOR DELETE TO authenticated
  USING (is_admin() AND (company_code = my_company() OR EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = trip_reassignments.ticket_id AND t.company_code = my_company())));

-- notifications: to/from people in your company
CREATE POLICY cs_all ON notifications FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM users u WHERE u.user_id = notifications.target_user_id AND u.company_code = my_company()))
  WITH CHECK (EXISTS (SELECT 1 FROM users u WHERE u.user_id = notifications.target_user_id AND u.company_code = my_company()));

-- analytics: your company's users
CREATE POLICY cs_all ON analytics FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM users u WHERE u.user_id = analytics.user_id AND u.company_code = my_company()))
  WITH CHECK (EXISTS (SELECT 1 FROM users u WHERE u.user_id = analytics.user_id AND u.company_code = my_company()));

-- ---------- 6. File storage: only logged-in phones can upload/change/delete ----------
DROP POLICY IF EXISTS "fleet_files_upload" ON storage.objects;
DROP POLICY IF EXISTS "fleet_files_update" ON storage.objects;
DROP POLICY IF EXISTS "fleet_files_delete" ON storage.objects;
CREATE POLICY "fleet_files_upload" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('challan-documents','trip-documents','driver-documents') AND my_company() IS NOT NULL);
CREATE POLICY "fleet_files_update" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id IN ('challan-documents','trip-documents','driver-documents') AND my_company() IS NOT NULL);
CREATE POLICY "fleet_files_delete" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id IN ('challan-documents','trip-documents','driver-documents') AND is_admin());

-- ============================================================
-- DONE. Expected result: "Success. No rows returned".
-- ============================================================
