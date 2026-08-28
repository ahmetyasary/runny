-- Profil detay alanları (SQL Editor'da çalıştır)
-- Meslek, yaş, konum, sporlar, ekipmanlar

alter table public.profiles
  add column if not exists profession text,
  add column if not exists age integer,
  add column if not exists location text,
  add column if not exists sports text[] not null default '{}',
  add column if not exists equipment text[] not null default '{}';

-- Yüzme aktivite tipini de destekle
alter table public.activities drop constraint if exists activities_type_check;
alter table public.activities
  add constraint activities_type_check
  check (type in ('run', 'walk', 'bike', 'hike', 'swim'));
