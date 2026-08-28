-- API rollerine tablo erişimi (RLS politikaları ayrıca da gerekli)
grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on table public.profiles to anon, authenticated;
grant select, insert, update, delete on table public.activities to anon, authenticated;
grant select, insert, update, delete on table public.activity_points to anon, authenticated;
grant select, insert, update, delete on table public.follows to anon, authenticated;
grant select, insert, update, delete on table public.likes to anon, authenticated;
grant select, insert, update, delete on table public.comments to anon, authenticated;

grant all on table public.profiles to service_role;
grant all on table public.activities to service_role;
grant all on table public.activity_points to service_role;
grant all on table public.follows to service_role;
grant all on table public.likes to service_role;
grant all on table public.comments to service_role;

grant usage, select on all sequences in schema public to anon, authenticated, service_role;
