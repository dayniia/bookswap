-- Stage 6: messages table for real-time chat between swap partners.
-- Run in Supabase SQL Editor.

drop table if exists public.messages cascade;

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  swap_request_id uuid not null references public.swap_requests(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  content text not null check (char_length(content) > 0),
  created_at timestamptz not null default now()
);

alter table public.messages enable row level security;

-- Only the two parties of the swap can read messages
create policy "swap parties can read messages"
  on public.messages for select
  using (
    exists (
      select 1 from public.swap_requests sr
      where sr.id = swap_request_id
        and (sr.requester_id = auth.uid() or sr.owner_id = auth.uid())
    )
  );

-- Only the two parties can send messages
create policy "swap parties can send messages"
  on public.messages for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.swap_requests sr
      where sr.id = swap_request_id
        and (sr.requester_id = auth.uid() or sr.owner_id = auth.uid())
    )
  );

-- Enable Realtime for the messages table
alter publication supabase_realtime add table public.messages;
