-- ============================================================
-- STORAGE BUCKET POLICIES
-- Run this in Supabase SQL Editor
-- Fixes 403 Unauthorized error on challan/upload
-- ============================================================

-- 1. Allow authenticated users to UPLOAD to challan-documents bucket
-- ============================================================
CREATE POLICY "Allow authenticated uploads to challan-documents"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'challan-documents'
  AND auth.role() = 'authenticated'
);

-- 2. Allow anyone to VIEW/READ from challan-documents bucket
-- ============================================================
CREATE POLICY "Allow public read access to challan-documents"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'challan-documents'
);

-- 3. Allow authenticated users to UPLOAD to trip-documents bucket
-- ============================================================
CREATE POLICY "Allow authenticated uploads to trip-documents"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'trip-documents'
  AND auth.role() = 'authenticated'
);

-- 4. Allow anyone to VIEW/READ from trip-documents bucket
-- ============================================================
CREATE POLICY "Allow public read access to trip-documents"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'trip-documents'
);

-- 5. Allow authenticated users to UPDATE (upsert) in both buckets
-- ============================================================
CREATE POLICY "Allow authenticated updates to challan-documents"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'challan-documents'
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Allow authenticated updates to trip-documents"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'trip-documents'
  AND auth.role() = 'authenticated'
);

-- ============================================================
-- END OF STORAGE POLICIES
-- ============================================================
