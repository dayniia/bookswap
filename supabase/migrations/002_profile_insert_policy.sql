-- Stage 2 patch: allow authenticated users to insert their own profile row.
-- Run this in Supabase SQL Editor after 001_schema.sql.

create policy "users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);
