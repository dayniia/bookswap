-- Stage 4 patch: Storage policies for listing-photos bucket.
-- Prerequisite: create the 'listing-photos' bucket in Supabase Storage
--   (Dashboard → Storage → New bucket → name: listing-photos → Public: ON).
-- Then run this SQL to allow authenticated users to upload.

-- Allow authenticated users to upload photos
create policy "authenticated users can upload listing photos"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'listing-photos');

-- Allow authenticated users to update/replace their own photos
create policy "users can update their own listing photos"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'listing-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow authenticated users to delete their own photos
create policy "users can delete their own listing photos"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'listing-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Public read (already covered by public bucket, but explicit is clearer)
create policy "listing photos are publicly readable"
  on storage.objects for select
  using (bucket_id = 'listing-photos');
