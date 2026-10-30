-- ============================================================
-- Chakka Saarthi — update 2
-- Run in Supabase → SQL Editor → New query → Run.
-- Needs security_and_features.sql to have been run first. Safe to run again.
-- ============================================================

-- 1. Log in with User ID *or* mobile number + MPIN
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
    -- MPIN login: the first box may hold the User ID or the mobile number
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
        RAISE EXCEPTION 'MPIN not set yet. Tap "First time? Set up your MPIN" and log in with your User ID and mobile number.';
      END IF;
      RAISE EXCEPTION 'Wrong User ID / mobile number or MPIN';
    END IF;
  ELSE
    -- First-time login: User ID + mobile number
    SELECT * INTO u FROM users WHERE UPPER(user_id) = UPPER(v_id) AND is_active;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid User ID';
    END IF;
    IF u.mobile IS DISTINCT FROM TRIM(COALESCE(p_mobile, '')) THEN
      RAISE EXCEPTION 'Invalid User ID or mobile number';
    END IF;
    IF NOT u.is_first_login THEN
      RAISE EXCEPTION 'MPIN already set. Please log in with your MPIN.';
    END IF;
  END IF;

  INSERT INTO app_sessions (auth_uid, user_id, company_code)
  VALUES (auth.uid(), u.user_id, u.company_code)
  ON CONFLICT (auth_uid) DO UPDATE
    SET user_id = EXCLUDED.user_id, company_code = EXCLUDED.company_code, created_at = NOW();

  RETURN (to_jsonb(u) - 'mpin_hash' - 'fcm_token')::json;
END $$;
REVOKE ALL ON FUNCTION app_login(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION app_login(TEXT, TEXT, TEXT) TO authenticated;

-- 2. Remember who did the unloading (a trip can change driver on the way)
ALTER TABLE unloading_status ADD COLUMN IF NOT EXISTS unloaded_by TEXT;

-- 3. Only the driver the trip is assigned to RIGHT NOW (or an admin) can fill in
--    loading/unloading. A driver whose trip was re-assigned is locked out.
DROP POLICY IF EXISTS cs_all ON loading_status;
DROP POLICY IF EXISTS cs_read ON loading_status;
DROP POLICY IF EXISTS cs_write ON loading_status;
CREATE POLICY cs_read ON loading_status FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = loading_status.ticket_id AND t.company_code = my_company()));
CREATE POLICY cs_write ON loading_status FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = loading_status.ticket_id AND t.company_code = my_company()
                 AND (is_admin() OR t.driver_user_id = my_user_id())))
  WITH CHECK (EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = loading_status.ticket_id AND t.company_code = my_company()
                 AND (is_admin() OR t.driver_user_id = my_user_id())));

DROP POLICY IF EXISTS cs_all ON unloading_status;
DROP POLICY IF EXISTS cs_read ON unloading_status;
DROP POLICY IF EXISTS cs_write ON unloading_status;
CREATE POLICY cs_read ON unloading_status FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = unloading_status.ticket_id AND t.company_code = my_company()));
CREATE POLICY cs_write ON unloading_status FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = unloading_status.ticket_id AND t.company_code = my_company()
                 AND (is_admin() OR t.driver_user_id = my_user_id())))
  WITH CHECK (EXISTS (SELECT 1 FROM tickets t WHERE t.ticket_id = unloading_status.ticket_id AND t.company_code = my_company()
                 AND (is_admin() OR t.driver_user_id = my_user_id())));

-- Trips: drivers may only update trips currently assigned to them
DROP POLICY IF EXISTS cs_update ON tickets;
CREATE POLICY cs_update ON tickets FOR UPDATE TO authenticated
  USING (company_code = my_company() AND (is_admin() OR driver_user_id = my_user_id()))
  WITH CHECK (company_code = my_company());

-- ============================================================
-- DONE. Expected: "Success. No rows returned".
-- ============================================================
