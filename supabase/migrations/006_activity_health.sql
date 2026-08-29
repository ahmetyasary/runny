-- Aktivite sağlık metrikleri (saat / HealthKit)
alter table public.activities
  add column if not exists elevation_gain_meters numeric not null default 0;

alter table public.activities
  add column if not exists avg_heart_rate integer;

alter table public.activities
  add column if not exists max_heart_rate integer;
