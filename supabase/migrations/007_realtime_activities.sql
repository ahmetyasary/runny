-- Aktivite insert'lerini realtime yayınla (Akış "Yeni aktiviteler" bildirimi).
-- Supabase Dashboard > SQL Editor'da bir kez çalıştır.

do $$
begin
  alter publication supabase_realtime add table public.activities;
exception
  when duplicate_object then null;
  when undefined_object then
    raise notice 'supabase_realtime publication bulunamadı — Dashboard > Database > Replication üzerinden activities tablosunu aç.';
end $$;
