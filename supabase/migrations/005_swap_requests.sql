-- Stage 5 patch: drop and recreate swap_requests with owner_id column.
-- Safe to run even if the table already exists (drops first).

drop table if exists public.swap_requests cascade;

create table public.swap_requests (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (listing_id, requester_id)
);

alter table public.swap_requests enable row level security;

create policy "requesters see their own requests"
  on public.swap_requests for select
  using (auth.uid() = requester_id);

create policy "owners see requests on their listings"
  on public.swap_requests for select
  using (auth.uid() = owner_id);

create policy "users can request swaps"
  on public.swap_requests for insert
  to authenticated
  with check (
    auth.uid() = requester_id
    AND auth.uid() != owner_id
  );

create policy "owners and requesters can update status"
  on public.swap_requests for update
  using (auth.uid() = owner_id OR auth.uid() = requester_id);
