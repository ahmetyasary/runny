-- Fix: club_members RLS infinite recursion (42P17)
-- SECURITY DEFINER yardımcıları RLS'yi baypas eder; politikalar birbirini tekrar çağırmaz.

create or replace function public.is_club_member(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.club_members
    where club_id = p_club_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.is_club_owner(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.clubs
    where id = p_club_id
      and owner_id = auth.uid()
  );
$$;

create or replace function public.is_public_club(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.clubs
    where id = p_club_id
      and is_public = true
  );
$$;

revoke all on function public.is_club_member(uuid) from public;
revoke all on function public.is_club_owner(uuid) from public;
revoke all on function public.is_public_club(uuid) from public;
grant execute on function public.is_club_member(uuid) to anon, authenticated;
grant execute on function public.is_club_owner(uuid) to anon, authenticated;
grant execute on function public.is_public_club(uuid) to anon, authenticated;

-- Clubs
drop policy if exists clubs_select on public.clubs;
create policy clubs_select on public.clubs
  for select to authenticated
  using (
    is_public
    or owner_id = auth.uid()
    or public.is_club_member(id)
  );

drop policy if exists clubs_select_anon on public.clubs;
create policy clubs_select_anon on public.clubs
  for select to anon
  using (is_public = true);

-- Members (kendi satırını / public kulüp üyelerini / sahip olduğu kulübü görebilir)
drop policy if exists club_members_select on public.club_members;
create policy club_members_select on public.club_members
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_public_club(club_id)
    or public.is_club_owner(club_id)
  );

drop policy if exists club_members_select_anon on public.club_members;
create policy club_members_select_anon on public.club_members
  for select to anon
  using (public.is_public_club(club_id));

drop policy if exists club_members_insert on public.club_members;
create policy club_members_insert on public.club_members
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (
      public.is_public_club(club_id)
      or public.is_club_owner(club_id)
    )
  );

drop policy if exists club_members_delete on public.club_members;
create policy club_members_delete on public.club_members
  for delete to authenticated
  using (
    user_id = auth.uid()
    or public.is_club_owner(club_id)
  );

-- Events
drop policy if exists club_events_select on public.club_events;
create policy club_events_select on public.club_events
  for select to authenticated
  using (
    public.is_public_club(club_id)
    or public.is_club_owner(club_id)
    or public.is_club_member(club_id)
  );

drop policy if exists club_events_select_anon on public.club_events;
create policy club_events_select_anon on public.club_events
  for select to anon
  using (public.is_public_club(club_id));

drop policy if exists club_events_insert on public.club_events;
create policy club_events_insert on public.club_events
  for insert to authenticated
  with check (
    created_by = auth.uid()
    and (
      public.is_club_owner(club_id)
      or public.is_club_member(club_id)
    )
  );

drop policy if exists club_events_delete on public.club_events;
create policy club_events_delete on public.club_events
  for delete to authenticated
  using (
    created_by = auth.uid()
    or public.is_club_owner(club_id)
  );
