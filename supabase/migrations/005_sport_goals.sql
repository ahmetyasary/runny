-- Spor hedefleri (haftalık km veya seans)
-- SQL Editor'da çalıştır veya: supabase db push

alter table public.profiles
  add column if not exists sport_goals jsonb not null default '{}'::jsonb;
