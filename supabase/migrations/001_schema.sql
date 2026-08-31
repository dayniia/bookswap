# BookSwap Ethiopia — Supabase Postgres Schema (v1 / MVP)
# Designed for: free direct 1:1 swaps, English + Amharic, city-scoped but
# city is data (not hardcoded), Telegram + email auth.
#
# Run this in Supabase SQL Editor → New query → Run.
# The 5 launch cities are seeded at the bottom — no extra seeding step needed.

-- ============================================================
-- 1. Reference data: cities
-- ============================================================
create table public.cities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,           -- e.g. 'Addis Ababa'
  created_at timestamptz not null default now()
);

-- Seed the 5 launch cities — add more rows here later to expand, no code changes needed.
insert into public.cities (name) values
  ('Addis Ababa'),
  ('Adama'),
  ('Bahir Dar'),
  ('Hawassa'),
  ('Mekelle');

-- ============================================================
-- 2. Profiles (extends Supabase auth.users)
-- ============================================================
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  city_id uuid references public.cities(id),
  area_note text,                       -- free text, e.g. "Bole, near Medhanialem church"
  language_pref text not null default 'en' check (language_pref in ('en', 'am')),
  telegram_id bigint unique,            -- nullable; set if user logged in via Telegram
  rating_avg numeric(3,2) not null default 0,
  rating_count int not null default 0,
  created_at timestamptz not null default now()
);

-- ============================================================
-- 3. Books & Listings
-- ============================================================
create table public.books (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  author text,
  isbn text,                            -- nullable: many local/Amharic books won't have one
  language text not null default 'en' check (language in ('en', 'am', 'other')),
  genre text,
  created_at timestamptz not null default now()
);

create index on public.books using gin (to_tsvector('simple', title || ' ' || coalesce(author, '')));

create type listing_status as enum ('available', 'pending', 'swapped', 'removed');
create type listing_condition as enum ('new', 'like_new', 'good', 'fair', 'worn');

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.books(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  condition listing_condition not null,
  photo_urls text[] not null default '{}',
  status listing_status not null default 'available',
  city_id uuid not null references public.cities(id),
  meeting_note text,                    -- free text, e.g. "Bole, near Medhanialem church"
  created_at timestamptz not null default now()
);

create index on public.listings (city_id, status);
create index on public.listings (owner_id);

-- ============================================================
-- 4. Swap requests (direct 1:1 only — no credits)
-- ============================================================
create type swap_status as enum ('pending', 'accepted', 'declined', 'completed', 'cancelled');

create table public.swap_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  wanted_listing_id uuid not null references public.listings(id) on delete cascade,
  offered_listing_id uuid not null references public.listings(id) on delete cascade,
  status swap_status not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  completed_at timestamptz,
  check (wanted_listing_id <> offered_listing_id)
);

create index on public.swap_requests (requester_id);
create index on public.swap_requests (wanted_listing_id);

-- ============================================================
-- 5. Chat messages (tied to a swap request)
-- ============================================================
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  swap_request_id uuid not null references public.swap_requests(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  sent_at timestamptz not null default now()
);

create index on public.messages (swap_request_id, sent_at);

-- ============================================================
-- 6. Ratings
-- ============================================================
create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  swap_request_id uuid not null references public.swap_requests(id) on delete cascade,
  rater_id uuid not null references public.profiles(id) on delete cascade,
  ratee_id uuid not null references public.profiles(id) on delete cascade,
  score smallint not null check (score between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  unique (swap_request_id, rater_id)
);

-- ============================================================
-- 7. Wishlist
-- ============================================================
create table public.wishlist_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  query_title text,
  query_author text,
  created_at timestamptz not null default now()
);

-- ============================================================
-- 8. Telegram login support
-- ============================================================
create table public.telegram_login_requests (
  login_token uuid primary key default gen_random_uuid(),
  telegram_id bigint,
  telegram_username text,
  verified boolean not null default false,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '10 minutes')
);

-- ============================================================
-- 9. Row Level Security
-- ============================================================
alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.swap_requests enable row level security;
alter table public.messages enable row level security;
alter table public.ratings enable row level security;
alter table public.wishlist_items enable row level security;

create policy "profiles are viewable by authenticated users"
  on public.profiles for select
  using (auth.role() = 'authenticated');

create policy "users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "listings are viewable by authenticated users"
  on public.listings for select
  using (auth.role() = 'authenticated');

create policy "owners can manage their own listings"
  on public.listings for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "participants can view their swap requests"
  on public.swap_requests for select
  using (
    auth.uid() = requester_id
    or auth.uid() in (
      select owner_id from public.listings where id = wanted_listing_id
    )
  );

create policy "requester can create swap requests"
  on public.swap_requests for insert
  with check (auth.uid() = requester_id);

create policy "participants can update swap request status"
  on public.swap_requests for update
  using (
    auth.uid() = requester_id
    or auth.uid() in (
      select owner_id from public.listings where id = wanted_listing_id
    )
  );

create policy "participants can view messages"
  on public.messages for select
  using (
    exists (
      select 1 from public.swap_requests sr
      where sr.id = swap_request_id
        and (
          auth.uid() = sr.requester_id
          or auth.uid() in (select owner_id from public.listings where id = sr.wanted_listing_id)
        )
    )
  );

create policy "participants can send messages"
  on public.messages for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.swap_requests sr
      where sr.id = swap_request_id
        and (
          auth.uid() = sr.requester_id
          or auth.uid() in (select owner_id from public.listings where id = sr.wanted_listing_id)
        )
    )
  );

create policy "ratings are viewable by authenticated users"
  on public.ratings for select
  using (auth.role() = 'authenticated');

create policy "rater can insert their own rating"
  on public.ratings for insert
  with check (
    auth.uid() = rater_id
    and exists (
      select 1 from public.swap_requests sr
      where sr.id = swap_request_id and sr.status = 'completed'
    )
  );

create policy "users manage their own wishlist"
  on public.wishlist_items for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Note: telegram_login_requests intentionally has NO public RLS policy —
-- it should only ever be read/written by Edge Functions using the service role key.
alter table public.telegram_login_requests enable row level security;
