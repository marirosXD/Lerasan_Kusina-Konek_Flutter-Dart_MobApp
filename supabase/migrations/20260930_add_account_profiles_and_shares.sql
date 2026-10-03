-- Account profile fields, owner profile photo storage, share history, and self-service deletion.

alter table public.users
  add column if not exists email text,
  add column if not exists bio text not null default '',
  add column if not exists avatar_url text not null default '';

update public.users as profile
set email = account.email
from auth.users as account
where profile.id = account.id and profile.email is distinct from account.email;

insert into public.users (id, full_name, email)
select
  id,
  coalesce(raw_user_meta_data ->> 'full_name', split_part(coalesce(email, ''), '@', 1), 'Home Cook'),
  email
from auth.users
on conflict (id) do nothing;

alter table public.users enable row level security;
drop policy if exists "Profiles are visible to signed-in users" on public.users;
create policy "Profiles are visible to signed-in users" on public.users
  for select to authenticated using (true);
drop policy if exists "Users update their own profile" on public.users;
create policy "Users update their own profile" on public.users
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
grant select, update on public.users to authenticated;

create table if not exists public.post_shares (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  shared_at timestamptz not null default now()
);

create index if not exists post_shares_user_id_idx on public.post_shares (user_id, shared_at desc);
create index if not exists post_shares_post_id_idx on public.post_shares (post_id);

alter table public.post_shares enable row level security;
drop policy if exists "Users see their own shared recipes" on public.post_shares;
create policy "Users see their own shared recipes" on public.post_shares
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users record their own recipe shares" on public.post_shares;
create policy "Users record their own recipe shares" on public.post_shares
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users remove their own recipe shares" on public.post_shares;
create policy "Users remove their own recipe shares" on public.post_shares
  for delete to authenticated using (auth.uid() = user_id);
grant select, insert, delete on public.post_shares to authenticated;

insert into storage.buckets (id, name, public)
values ('profile_images', 'profile_images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Profile photos are public" on storage.objects;
create policy "Profile photos are public" on storage.objects
  for select to public using (bucket_id = 'profile_images');
drop policy if exists "Users upload their own profile photos" on storage.objects;
create policy "Users upload their own profile photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'profile_images' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Users update their own profile photos" on storage.objects;
create policy "Users update their own profile photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'profile_images' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'profile_images' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Users delete their own profile photos" on storage.objects;
create policy "Users delete their own profile photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'profile_images' and (storage.foldername(name))[1] = auth.uid()::text);

create or replace function public.sync_auth_email_to_profile()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  update public.users set email = new.email where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_updated on auth.users;
create trigger on_auth_user_email_updated
  after update of email on auth.users
  for each row when (old.email is distinct from new.email)
  execute procedure public.sync_auth_email_to_profile();

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'You must be signed in to delete your account.';
  end if;
  delete from auth.users where id = current_user_id;
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_shares'
  ) then
    alter publication supabase_realtime add table public.post_shares;
  end if;
end;
$$;

notify pgrst, 'reload schema';
