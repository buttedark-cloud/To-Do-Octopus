-- Хранилище картинок (Supabase -> SQL Editor -> Run). Безопасно запускать повторно.
-- Каждый телефон входит в Supabase анонимно и получает свою папку <uid>/...
insert into storage.buckets (id, name, public)
values ('user-images', 'user-images', true)
on conflict (id) do nothing;

drop policy if exists "img select own" on storage.objects;
drop policy if exists "img insert own" on storage.objects;
drop policy if exists "img update own" on storage.objects;
drop policy if exists "img delete own" on storage.objects;

create policy "img select own" on storage.objects for select to authenticated
using (bucket_id = 'user-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "img insert own" on storage.objects for insert to authenticated
with check (bucket_id = 'user-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "img update own" on storage.objects for update to authenticated
using (bucket_id = 'user-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "img delete own" on storage.objects for delete to authenticated
using (bucket_id = 'user-images' and (storage.foldername(name))[1] = auth.uid()::text);
