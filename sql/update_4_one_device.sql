-- ============================================================
-- Chakka Saarthi — update 4: a driver can be logged in on ONE phone only
-- Run in Supabase → SQL Editor → New query → Run (after updates 1–3). Safe to run again.
-- ============================================================

-- 1. Login: refuse a driver who is already logged in on a different phone
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
        RAISE EXCEPTION 'MPIN not set yet. Tap "First time? Set up your MPIN" and log in with your User ID and mobile number.';
      END IF;
      RAISE EXCEPTION 'Wrong User ID / mobile number or MPIN';
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
      RAISE EXCEPTION 'MPIN already set. Please log in with your MPIN.';
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

-- 2. Admin: log a driver out of every phone (lost/changed phone)
CREATE OR REPLACE FUNCTION admin_logout_user(p_user_id TEXT) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n INT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only an admin can do this';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id AND company_code = my_company()) THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  DELETE FROM app_sessions WHERE user_id = p_user_id;
  GET DIAGNOSTICS n = ROW_COUNT;
  UPDATE users SET fcm_token = NULL WHERE user_id = p_user_id;
  RETURN n;
END $$;
REVOKE ALL ON FUNCTION admin_logout_user(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION admin_logout_user(TEXT) TO authenticated;

-- 3. Start clean: drivers logged in on several phones today keep only their most recent one
DELETE FROM app_sessions s
USING users u
WHERE u.user_id = s.user_id AND u.role = 'driver'
  AND s.created_at < (SELECT MAX(s2.created_at) FROM app_sessions s2 WHERE s2.user_id = s.user_id);

-- ============================================================
-- DONE. Expected: "Success. No rows returned".
-- ============================================================
