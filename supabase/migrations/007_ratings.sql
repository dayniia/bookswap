-- Stage 7: ratings table + mark-as-swapped status.
-- Run in Supabase SQL Editor.

-- 1. Drop and recreate ratings (handles if schema already has it)
drop table if exists public.ratings cascade;

create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  swap_request_id uuid not null references public.swap_requests(id) on delete cascade,
  rater_id uuid not null references public.profiles(id) on delete cascade,
  rated_id uuid not null references public.profiles(id) on delete cascade,
  stars smallint not null check (stars between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  -- One rating per user per swap
  unique (swap_request_id, rater_id)
);

alter table public.ratings enable row level security;

-- Anyone can read ratings (for displaying average on profiles)
create policy "ratings are publicly readable"
  on public.ratings for select using (true);

-- Only the rater can insert their own rating
create policy "raters can insert their rating"
  on public.ratings for insert
  to authenticated
  with check (auth.uid() = rater_id);

-- 2. Add 'swapped' to swap_requests status check
-- (requires drop + recreate of the check constraint)
alter table public.swap_requests
  drop constraint if exists swap_requests_status_check;

alter table public.swap_requests
  add constraint swap_requests_status_check
  check (status in ('pending', 'accepted', 'declined', 'cancelled', 'swapped'));
