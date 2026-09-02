-- Stage 4 patch: recreate listings table with correct columns.
-- Safe to run even if listings exists — drops and recreates it.
-- Run this in Supabase SQL Editor.

drop table if exists public.listings cascade;

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  author text,
  language text not null default 'en',
  city_id uuid references public.cities(id),
  area_note text,
  condition text not null default 'good'
    check (condition in ('new', 'like_new', 'good', 'acceptable')),
  description text,
  photo_urls text[] not null default '{}',
  status text not null default 'available'
    check (status in ('available', 'pending', 'swapped', 'removed')),
  created_at timestamptz not null default now()
);

-- Row Level Security
alter table public.listings enable row level security;

create policy "anyone can view available listings"
  on public.listings for select
  using (status = 'available');

create policy "owners can insert their own listings"
  on public.listings for insert
  with check (auth.uid() = owner_id);

create policy "owners can update their own listings"
  on public.listings for update
  using (auth.uid() = owner_id);

create policy "owners can delete their own listings"
  on public.listings for delete
  using (auth.uid() = owner_id);
