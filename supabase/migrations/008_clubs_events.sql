-- Kulüpler, üyelik, etkinlikler ve katılımlar
-- SQL Editor'da çalıştırın (CLI yoksa).

create table if not exists public.clubs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  description text not null default '',
  sport text not null default 'Koşu',
  city text not null default '',
  is_public boolean not null default true,
  cover_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.club_members (
  club_id uuid not null references public.clubs (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

create table if not exists public.club_events (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  created_by uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  description text not null default '',
  sport text not null default 'Koşu',
  location_name text not null default '',
  starts_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.club_event_participants (
  event_id uuid not null references public.club_events (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create index if not exists clubs_owner_idx on public.clubs (owner_id);
create index if not exists clubs_public_idx on public.clubs (is_public, created_at desc);
create index if not exists club_members_user_idx on public.club_members (user_id);
create index if not exists club_events_starts_idx on public.club_events (starts_at);
create index if not exists club_events_club_idx on public.club_events (club_id, starts_at);

alter table public.clubs enable row level security;
alter table public.club_members enable row level security;
alter table public.club_events enable row level security;
alter table public.club_event_participants enable row level security;

-- Clubs
drop policy if exists clubs_select on public.clubs;
create policy clubs_select on public.clubs
  for select to authenticated
  using (
    is_public
    or owner_id = auth.uid()
    or exists (
      select 1 from public.club_members m
      where m.club_id = clubs.id and m.user_id = auth.uid()
    )
  );

drop policy if exists clubs_insert on public.clubs;
create policy clubs_insert on public.clubs
  for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists clubs_update on public.clubs;
create policy clubs_update on public.clubs
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists clubs_delete on public.clubs;
create policy clubs_delete on public.clubs
  for delete to authenticated
  using (owner_id = auth.uid());

-- Members
drop policy if exists club_members_select on public.club_members;
create policy club_members_select on public.club_members
  for select to authenticated
  using (
    exists (
      select 1 from public.clubs c
      where c.id = club_members.club_id
        and (
          c.is_public
          or c.owner_id = auth.uid()
          or exists (
            select 1 from public.club_members m2
            where m2.club_id = c.id and m2.user_id = auth.uid()
          )
        )
    )
  );

drop policy if exists club_members_insert on public.club_members;
create policy club_members_insert on public.club_members
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.clubs c
      where c.id = club_id
        and (c.is_public or c.owner_id = auth.uid())
    )
  );

drop policy if exists club_members_delete on public.club_members;
create policy club_members_delete on public.club_members
  for delete to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.clubs c
      where c.id = club_members.club_id and c.owner_id = auth.uid()
    )
  );

-- Events
drop policy if exists club_events_select on public.club_events;
create policy club_events_select on public.club_events
  for select to authenticated
  using (
    exists (
      select 1 from public.clubs c
      where c.id = club_events.club_id
        and (
          c.is_public
          or c.owner_id = auth.uid()
          or exists (
            select 1 from public.club_members m
            where m.club_id = c.id and m.user_id = auth.uid()
          )
        )
    )
  );

drop policy if exists club_events_insert on public.club_events;
create policy club_events_insert on public.club_events
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and (
      exists (
        select 1 from public.clubs c
        where c.id = club_id and c.owner_id = auth.uid()
      )
      or exists (
        select 1 from public.club_members m
        where m.club_id = club_id and m.user_id = auth.uid()
      )
    )
  );

drop policy if exists club_events_delete on public.club_events;
create policy club_events_delete on public.club_events
  for delete to authenticated
  using (
    created_by = auth.uid()
    or exists (
      select 1 from public.clubs c
      where c.id = club_events.club_id and c.owner_id = auth.uid()
    )
  );

-- Participants
drop policy if exists club_event_participants_select on public.club_event_participants;
create policy club_event_participants_select on public.club_event_participants
  for select to authenticated
  using (true);

drop policy if exists club_event_participants_insert on public.club_event_participants;
create policy club_event_participants_insert on public.club_event_participants
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists club_event_participants_delete on public.club_event_participants;
create policy club_event_participants_delete on public.club_event_participants
  for delete to authenticated
  using (user_id = auth.uid());

grant select on table public.clubs to anon, authenticated;
grant select, insert, update, delete on table public.clubs to authenticated;
grant select on table public.club_members to anon, authenticated;
grant select, insert, update, delete on table public.club_members to authenticated;
grant select on table public.club_events to anon, authenticated;
grant select, insert, update, delete on table public.club_events to authenticated;
grant select on table public.club_event_participants to anon, authenticated;
grant select, insert, update, delete on table public.club_event_participants to authenticated;

grant all on table public.clubs to service_role;
grant all on table public.club_members to service_role;
grant all on table public.club_events to service_role;
grant all on table public.club_event_participants to service_role;
