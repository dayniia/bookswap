# BookSwap  Build Guide
 
This is a self-contained brief . Paste the relevant sections in as you go
through the phases below, in order. Each phase ends with a suggested prompt you can copy
directly into IDE. Don't skip ahead — each phase assumes the previous one is working.
 
---
 
## 0. Project summary (paste this once, at the start of your first  session)
 
**What we're building:** A free book-swapping app for Ethiopia. Users list books they own,
browse books others have listed, request a direct 1:1 swap (your book for theirs), chat to
arrange a handoff, and rate each other afterward. No money changes hands. No credits system —
pure direct swap only.
 
**Scope for v1:**
- 5 cities at launch — Addis Ababa, Adama, Bahir Dar, Hawassa, Mekelle (easy to change: this
  is just seed data, swap in whichever 5 you actually want) — architected so adding more
  cities later is a data change, not a code change
- English + Amharic UI and content
- Auth via Telegram login and Email (no phone/OTP, no password-only signup)
- Barcode scanning for books that have an ISBN; manual entry fallback for books that don't
  (very common for local/Amharic titles)
- No live map, no subcity/neighborhood dropdown — location is a City dropdown plus a
  free-text "area/residence note" per user and per listing (e.g. "Bole, near Medhanialem
  church" or "Piassa, around the post office") — simpler than a maintained subcity list and
  works fine across cities with very different neighborhood-naming conventions
- Direct swap requests with accept/decline/counter-offer, in-app chat, post-swap ratings
**Explicitly out of scope for v1** (don't build these unless asked later):
- Any payment integration (Chapa or otherwise)
- Delivery/courier/shipping
- A credit-based swap economy
- Live maps / GPS
- A structured subcity/neighborhood table (free-text note covers this for now)
**Tech stack:**
- **Client:** Flutter — single codebase, targets both an Android APK and a web build
- **Backend:** Supabase (Postgres + Auth + Storage + Realtime + Edge Functions) — free tier
- **Barcode scanning:** `mobile_scanner` Flutter package (on-device, no external API)
- **Push notifications:** Firebase Cloud Messaging (v1.x, after core app works)
- **Auth:** Supabase's built-in Email (magic link) auth, plus a custom Telegram login flow
  (Supabase has no native Telegram provider — see Phase 3 below for the exact approach)
**Design principle to enforce throughout:** every city reference in the schema and code must
go through the `cities` table — never hardcode a city name in application logic. This is
what makes adding a 6th, 20th, or 100th city later free.
 
---
 
## 1. Database schema (Supabase)
 
Run this directly in the Supabase SQL editor before writing any app code. Create a new
Supabase project first (supabase.com, free tier), then paste this into SQL Editor → New query → Run.
 
```sql
-- BookSwap Ethiopia — Supabase Postgres Schema (v1 / MVP)
-- Designed for: free direct 1:1 swaps, English + Amharic, city-scoped but
-- city is data (not hardcoded), Telegram + email auth.
 
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
-- 8. Telegram login support (used by the telegram-webhook /
--    telegram-auth Edge Functions — see Phase 3 below)
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
```
 
The 5 launch cities are already seeded as part of the schema above — no separate seeding
step needed. If you want to change which cities launch first, edit the `insert into
public.cities` values before running this, or just update the rows afterward in the table
editor.
 
---
 
## 2. Phase-by-phase build plan
 
Work through these phases **in order** in Claude Code. Start a phase only once the previous
one runs and you've manually tested it.
 
### Phase 1 — Project scaffold
Set up the Flutter project, Supabase connection, and folder structure. No real features yet —
just prove the app builds for both Android and web and can talk to Supabase.
 
### Phase 2 — Auth (Email first, Telegram second)
Get Supabase email magic-link auth working end-to-end first (simpler, built-in). Only then
tackle Telegram login (custom, more moving parts — described fully in Phase 3 below).
 
### Phase 3 — Telegram login (the tricky part)
Supabase has no built-in Telegram provider. The flow:
1. Create a Telegram bot via **@BotFather** (free, few minutes) and get its bot token.
2. User taps "Log in with Telegram" in the app → app generates a random `login_token`
   (a UUID) and opens `https://t.me/YourBookSwapBot?start=<login_token>`.
3. User taps **Start** in Telegram → Telegram calls your bot's webhook, which is a
   **Supabase Edge Function** (`telegram-webhook`). That function reads the `login_token`
   from the `/start` payload plus the user's Telegram ID/username, and writes/updates a row
   in `telegram_login_requests` marking it `verified = true` with the Telegram ID attached.
4. Meanwhile, the app **subscribes via Supabase Realtime** to that specific row (matching on
   `login_token`) and waits for `verified` to flip to true.
5. Once verified, a second Edge Function (`telegram-auth`) uses the **Supabase service role
   key** to find-or-create a Supabase Auth user tied to that Telegram ID (e.g. a synthetic
   email like `tg_<telegram_id>@bookswap.internal`), then mints a session for the client
   (via `admin.generateLink` or by signing a session token) and returns it.
6. The app receives that session and signs in exactly like any other Supabase Auth session.
The two Edge Functions (`telegram-webhook`, `telegram-auth`) are the only genuinely custom
backend code in this whole project — everything else leans on Supabase's built-in Auth/DB/
Storage/Realtime.
 
### Phase 4 — Book listing (create + browse)
- Manual "add a book" form: title, author, language (English/Amharic/other), genre, condition,
  photo(s) via Supabase Storage, city (dropdown), and area/meeting note (free text).
- Barcode scan flow using `mobile_scanner`: scan ISBN → try to prefill title/author (via a
  free public book-lookup API such as Open Library's API, no key required) → user confirms/
  edits → falls back gracefully to full manual entry if no match is found (very common case
  for local/Amharic titles — don't treat this as an error state, treat it as normal).
- Browse screen: list/grid of available listings filtered by City (dropdown, one of the 5
  launch cities), with a language toggle (English/Amharic) and basic search by title/author.
  Each listing shows its free-text area note so the requester can judge proximity themselves.
### Phase 5 — Swap requests, counter-offers, chat
- From a listing, "Request swap" lets the requester pick one of their own available listings
  to offer in return.
- Listing owner sees incoming requests, can Accept / Decline / Counter (propose a different
  one of the requester's books instead).
- Once accepted, open a chat thread (Supabase Realtime) scoped to that `swap_request` for
  arranging the in-person handoff — include the `meeting_note` from both listings prominently
  since there's no live map.
- Mark swap `completed` or `cancelled` from either side.
### Phase 6 — Ratings & profile
- After a swap is marked `completed`, prompt both sides to rate each other (1–5 + optional
  comment).
- Show `rating_avg` / `rating_count` on profiles and listings so trust is visible before
  someone commits to a swap.
### Phase 7 — Amharic localization
- Add Flutter's `intl`/localization setup with `en` and `am` resource files.
- Make sure Amharic (Ge'ez script) renders correctly — pick a font (e.g. Noto Sans Ethiopic)
  and bundle it rather than relying on system fonts, since not all Android devices in the
  field will have good Ge'ez glyph coverage.
- Localize UI strings; book `language` metadata already supports Amharic content from Phase 4.
### Phase 8 — Wishlist + notifications (v1.x, after core loop works)
- Wishlist: user saves a title/author they want; when a matching listing appears in their
  city, notify them.
- Wire up Firebase Cloud Messaging for push notifications on: new swap request, new message,
  wishlist match.
### Phase 9 — Polish & moderation basics
- Report/flag a listing or user (simple table + admin view, doesn't need to be fancy for v1).
- Empty states, loading states, and offline-friendly image upload queuing (uploads should
  queue and retry rather than fail hard, given patchy connectivity).
- Test the full loop on a real low-end Android device on a throttled connection before
  considering v1 "done."
---
 
## 3. How to prompt for each phase
 
Use one prompt per phase, and don't move to the next phase's prompt until the current one
builds and runs. Suggested first prompt:
 
> I'm building "BookSwap Ethiopia," a free book-swap app. Here's the full project brief,
> database schema, and phase plan: [paste Section 0, 1, and 2 above]. Let's start with
> Phase 1 only: scaffold a new Flutter project that builds for both Android and web, add the
> `supabase_flutter` package, and wire up a Supabase client using environment-based config
> (don't hardcode keys). Set up a clean folder structure (e.g. `lib/features/...`,
> `lib/core/...`) that the later phases (auth, listings, swap requests, chat, ratings) can
> slot into. Don't build any feature screens yet — just prove the app runs and can reach
> Supabase.
 
For each subsequent phase, a good pattern is:
 
> Now let's do Phase [N]: [paste that phase's section from above]. Build on what we already
> have — don't restructure earlier phases unless something is actually broken.
 
If Claude Code ever proposes hardcoding "Addis Ababa" instead of reading from the `cities`
table, or proposes a payments/credits/live-map feature, point back to the "Explicitly out of
scope for v1" list in Section 0 and redirect it to the data-driven approach instead.
 
---
 
## 4. Step-by-step: setting up the accounts/services
 
Do these before starting Phase 1 in Claude Code. You'll end up with a small set of keys/IDs —
keep them somewhere safe (a password manager or a local `.env` file that's git-ignored).
 
### 4a. Supabase project
 
1. Go to **supabase.com** → sign up (GitHub or email) → **New project**.
2. Pick an organization (create one if it's your first project), name it (e.g. `bookswap-et`),
   set a strong database password (save it — you'll rarely need it directly, but Supabase
   asks for it during setup), and pick a region. Pick the region closest to your users that's
   offered — likely somewhere in Europe or the Middle East, since Supabase doesn't currently
   have an East Africa region; any of those will work fine for a project this size.
3. Wait ~2 minutes for the project to provision.
4. Once it's ready, go to **Project Settings → API**. You'll see:
   - **Project URL** — looks like `https://xxxxx.supabase.co`
   - **anon public key** — a long JWT string. This is safe to embed in the Flutter app.
   - **service_role key** — another long JWT string. **Never put this in the Flutter app** —
     it bypasses Row Level Security entirely. It only ever goes into Edge Function
     environment variables (server-side), for the Telegram auth flow in Phase 3.
5. Go to **SQL Editor → New query**, paste the schema from Section 1 above, and run it — this
   already seeds the 5 launch cities, no separate step needed.
6. Go to **Storage** → **New bucket** → name it `listing-photos` → keep it private for now
   (you'll serve images via signed URLs or make it public later once you're comfortable with
   the access pattern — private is the safer default to start with).
7. Give Claude Code the **Project URL** and **anon key** when it asks for Supabase config in
   Phase 1. Hold onto the **service_role key** for Phase 3 — don't paste it into chat or
   commit it to a public repo; put it in Supabase's Edge Function secrets (see 4b's later
   step, or `supabase secrets set` via the Supabase CLI) when you get there.
### 4b. Telegram bot via @BotFather
 
1. Open Telegram (app or web), search for **@BotFather**, and start a chat with it.
2. Send `/newbot`.
3. It'll ask for a **name** (display name, e.g. "BookSwap Ethiopia") and then a **username**
   (must be unique and end in `bot`, e.g. `BookSwapEthiopiaBot`).
4. BotFather replies with your **bot token** — a string like `123456789:ABCdefGhIJKlmNoPQRstuVWxyz`.
   This is the credential your `telegram-webhook` Edge Function will use to call the Telegram
   Bot API and to verify incoming updates. Keep it private, same handling as the Supabase
   service_role key.
5. Optional but nice: send `/setuserpic` to give the bot a logo, and `/setdescription` to add
   a short description users see before they tap Start.
6. You don't need to configure a webhook manually right now — that happens in Phase 3, when
   Claude Code builds the `telegram-webhook` Edge Function and you register its URL with
   Telegram via a one-time API call (`setWebhook`) using this bot token.
7. Give Claude Code the **bot token** when you reach Phase 3 (as an Edge Function secret, not
   hardcoded in the function source).
### 4c. Firebase project (for push notifications, Phase 8 — can wait until then)
 
1. Go to **console.firebase.google.com** → **Add project** → name it (e.g. `bookswap-et`) →
   you can decline Google Analytics for this project, it's not needed.
2. Once created, click **Add app** → choose **Android** (and later **Web**, if you want push
   on the web build too):
   - For Android: enter your app's package name (you'll define this in Phase 1's Flutter
     project setup, commonly something like `com.yourname.bookswap`) → download the generated
     `google-services.json` file → this goes into the Flutter project's `android/app/`
     folder — Claude Code will tell you exactly where when you reach Phase 8.
   - For Web: Firebase gives you a small config object (apiKey, projectId, etc.) to paste into
     the Flutter web setup.
3. In the Firebase console, go to **Project settings → Cloud Messaging** and confirm Cloud
   Messaging API is enabled (it usually is by default on new projects).
4. That's all you need to *set up* now — the actual FCM integration code happens in Phase 8.
   No need to touch this again until then.
### 4d. Before you open Claude Code: local prerequisites checklist
 
- **Flutter SDK** installed locally — run `flutter doctor` and make sure it passes (or at
  least shows Android toolchain + web support as ready) before starting Phase 1. Claude Code
  can help fix issues it reports, but the SDK itself needs to be on your machine.
- **Supabase CLI** (`npm install -g supabase`) — lets Claude Code manage schema migrations
  and run/deploy Edge Functions from the terminal instead of pasting SQL into the web editor
  by hand. Useful from Phase 1 onward, essential by Phase 3 (Telegram Edge Functions).
- **Firebase CLI** (`npm install -g firebase-tools`) — same reasoning, needed when you reach
  Phase 8 (Cloud Messaging). Not needed before then.
- Optional but recommended: connect the **Supabase MCP server** to Claude Code
  (`claude mcp add` or via Claude Code's connector settings) so Claude can query/manage your
  Supabase project directly — inspect tables, check RLS policies, run SQL — instead of you
  relaying results back and forth manually.
### Summary of what you'll be holding onto
 
| Value | Where it's used | Sensitivity |
|---|---|---|
| Supabase Project URL | Flutter app config | Safe to embed |
| Supabase anon key | Flutter app config | Safe to embed |
| Supabase service_role key | Edge Function secrets only | **Secret — never in the app** |
| Telegram bot token | Edge Function secrets only | **Secret — never in the app** |
| Firebase `google-services.json` / web config | Flutter app (Phase 8) | Safe to embed |
 
Also note for later, not needed yet:
- **Flutter SDK** installed locally, or let Claude Code install it in your dev environment
  when you start Phase 1.
- **Google Play developer account** ($25 one-time fee) — only needed once you're ready to
  actually publish the Android APK, not during development.
 