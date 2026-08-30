-- Kulüp tabloları için eksik GRANT'ler (008 kısmen uygulandıysa)
-- SQL Editor'da çalıştırın.

grant usage on schema public to anon, authenticated, service_role;

grant select on table public.clubs to anon, authenticated;
grant select, insert, update, delete on table public.clubs to authenticated;
grant all on table public.clubs to service_role;

grant select on table public.club_members to anon, authenticated;
grant select, insert, update, delete on table public.club_members to authenticated;
grant all on table public.club_members to service_role;

grant select on table public.club_events to anon, authenticated;
grant select, insert, update, delete on table public.club_events to authenticated;
grant all on table public.club_events to service_role;

grant select on table public.club_event_participants to anon, authenticated;
grant select, insert, update, delete on table public.club_event_participants to authenticated;
grant all on table public.club_event_participants to service_role;

-- Anon için herkese açık kulüp/etkinlik okuma (RLS)
drop policy if exists clubs_select_anon on public.clubs;
create policy clubs_select_anon on public.clubs
  for select to anon
  using (is_public = true);

drop policy if exists club_members_select_anon on public.club_members;
create policy club_members_select_anon on public.club_members
  for select to anon
  using (
    exists (
      select 1 from public.clubs c
      where c.id = club_members.club_id and c.is_public = true
    )
  );

drop policy if exists club_events_select_anon on public.club_events;
create policy club_events_select_anon on public.club_events
  for select to anon
  using (
    exists (
      select 1 from public.clubs c
      where c.id = club_events.club_id and c.is_public = true
    )
  );

drop policy if exists club_event_participants_select_anon on public.club_event_participants;
create policy club_event_participants_select_anon on public.club_event_participants
  for select to anon
  using (true);
