-- Aktivite tiplerini profil sporlarıyla hizala
alter table public.activities drop constraint if exists activities_type_check;
alter table public.activities
  add constraint activities_type_check
  check (type in ('run', 'walk', 'bike', 'hike', 'swim', 'trail', 'gym', 'yoga'));
