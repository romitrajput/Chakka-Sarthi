-- ============================================================
-- Chakka Saarthi — update 3
-- Run in Supabase → SQL Editor → New query → Run (after updates 1 and 2). Safe to run again.
-- ============================================================

-- 1. Consigner name, entered by the driver at unloading
ALTER TABLE unloading_status ADD COLUMN IF NOT EXISTS consigner_name TEXT;

-- 2. Drivers can create (self-assign) a trip — only for themselves, in their own company
DROP POLICY IF EXISTS cs_insert ON tickets;
CREATE POLICY cs_insert ON tickets FOR INSERT TO authenticated
  WITH CHECK (company_code = my_company() AND (is_admin() OR driver_user_id = my_user_id()));

-- 3. Aadhaar, licence, challan photos and trip PDFs: PRIVATE storage.
--    Files can no longer be opened by anyone with the link; only logged-in users of
--    the same company can see them (the app uses 1-hour signed links).
UPDATE storage.buckets SET public = false
  WHERE id IN ('challan-documents', 'trip-documents', 'driver-documents');

DROP POLICY IF EXISTS "fleet_files_read"   ON storage.objects;
DROP POLICY IF EXISTS "fleet_files_upload" ON storage.objects;
DROP POLICY IF EXISTS "fleet_files_update" ON storage.objects;
DROP POLICY IF EXISTS "fleet_files_delete" ON storage.objects;

-- Every file sits in a folder named after the company code, e.g. 01/MH01DR.../license.jpg
CREATE POLICY "fleet_files_read" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id IN ('challan-documents','trip-documents','driver-documents')
         AND (storage.foldername(name))[1] = my_company());
CREATE POLICY "fleet_files_upload" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('challan-documents','trip-documents','driver-documents')
              AND (storage.foldername(name))[1] = my_company());
CREATE POLICY "fleet_files_update" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id IN ('challan-documents','trip-documents','driver-documents')
         AND (storage.foldername(name))[1] = my_company());
CREATE POLICY "fleet_files_delete" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id IN ('challan-documents','trip-documents','driver-documents')
         AND (storage.foldername(name))[1] = my_company() AND is_admin());

-- Check: all three should show public = false
SELECT id, public FROM storage.buckets
  WHERE id IN ('challan-documents', 'trip-documents', 'driver-documents');
