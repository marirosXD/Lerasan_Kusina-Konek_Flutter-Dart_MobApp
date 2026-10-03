-- Kusina Konek database setup for a new Supabase project.
-- Run this once in Supabase Dashboard > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'Home Cook',
  bio text not null default '',
  avatar_url text not null default '',
  email text unique,
  created_at timestamptz not null default now()
);

alter table public.users add column if not exists email text;
alter table public.users add column if not exists bio text not null default '';
alter table public.users add column if not exists avatar_url text not null default '';

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  client_request_id text,
  author_name text not null default 'Home Cook',
  title text not null,
  instructions text not null default '',
  cooking_notes text not null default '',
  ingredients jsonb not null default '[]'::jsonb,
  image_url text not null default '',
  image_urls jsonb not null default '[]'::jsonb,
  tags jsonb not null default '[]'::jsonb,
  likes_count integer not null default 0 check (likes_count >= 0),
  prep_time_minutes integer not null default 0 check (prep_time_minutes >= 0),
  prep_time_value integer not null default 0 check (prep_time_value >= 0),
  prep_time_unit text not null default 'min' check (prep_time_unit in ('sec', 'min', 'hr')),
  servings integer not null default 1 check (servings > 0),
  region text not null default '',
  difficulty text not null default 'Easy' check (difficulty in ('Easy', 'Medium', 'Hard')),
  created_at timestamptz not null default now()
);

alter table public.posts add column if not exists ingredients jsonb not null default '[]'::jsonb;
alter table public.posts add column if not exists author_name text not null default 'Home Cook';
alter table public.posts add column if not exists client_request_id text;
alter table public.posts add column if not exists cooking_notes text not null default '';
alter table public.posts add column if not exists image_url text not null default '';
alter table public.posts add column if not exists image_urls jsonb not null default '[]'::jsonb;
alter table public.posts add column if not exists tags jsonb not null default '[]'::jsonb;
alter table public.posts add column if not exists likes_count integer not null default 0;
alter table public.posts add column if not exists prep_time_minutes integer not null default 0;
alter table public.posts add column if not exists prep_time_value integer not null default 0;
alter table public.posts add column if not exists prep_time_unit text not null default 'min';
alter table public.posts add column if not exists servings integer not null default 1;
alter table public.posts add column if not exists region text not null default '';
alter table public.posts add column if not exists difficulty text not null default 'Easy';

update public.posts
set prep_time_value = prep_time_minutes
where prep_time_value = 0 and prep_time_minutes > 0;
alter table public.posts add column if not exists created_at timestamptz not null default now();

create table if not exists public.interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  interaction_type text not null check (interaction_type in ('like', 'comment', 'save')),
  comment_text text,
  parent_comment_id uuid references public.interactions(id) on delete cascade,
  user_name text,
  tags jsonb not null default '[]'::jsonb,
  weight double precision not null default 1,
  created_at timestamptz not null default now()
);

alter table public.interactions
  add column if not exists parent_comment_id uuid
  references public.interactions(id) on delete cascade;

create table if not exists public.saved_collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  collection_name text not null,
  saved_post_ids jsonb not null default '[]'::jsonb,
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, collection_name)
);

create table if not exists public.post_likes (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table if not exists public.comment_likes (
  comment_id uuid not null references public.interactions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

create table if not exists public.post_shares (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  shared_at timestamptz not null default now()
);

create index if not exists posts_created_at_idx on public.posts (created_at desc);
create index if not exists posts_author_id_idx on public.posts (author_id);
create unique index if not exists posts_author_client_request_idx
  on public.posts (author_id, client_request_id)
  where client_request_id is not null;
create index if not exists interactions_user_id_idx on public.interactions (user_id);
create index if not exists interactions_post_id_idx on public.interactions (post_id);
create index if not exists collections_user_id_idx on public.saved_collections (user_id);
create index if not exists post_likes_post_id_idx on public.post_likes (post_id);
create index if not exists comment_likes_comment_id_idx on public.comment_likes (comment_id);
create index if not exists post_shares_user_id_idx on public.post_shares (user_id, shared_at desc);
create index if not exists post_shares_post_id_idx on public.post_shares (post_id);

create or replace function public.update_post_like_count()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set likes_count = likes_count + 1 where id = new.post_id;
    return new;
  end if;
  update public.posts set likes_count = greatest(likes_count - 1, 0) where id = old.post_id;
  return old;
end;
$$;

drop trigger if exists post_like_count_changed on public.post_likes;
create trigger post_like_count_changed
  after insert or delete on public.post_likes
  for each row execute procedure public.update_post_like_count();

create or replace function public.toggle_post_like(target_post_id uuid)
returns boolean
language plpgsql
security definer set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  liked_now boolean;
begin
  if current_user_id is null then
    raise exception 'You must be signed in to like a recipe.';
  end if;
  if not exists (select 1 from public.posts where id = target_post_id) then
    raise exception 'Recipe not found.';
  end if;

  if exists (
    select 1 from public.post_likes
    where user_id = current_user_id and post_id = target_post_id
  ) then
    delete from public.post_likes
    where user_id = current_user_id and post_id = target_post_id;
    return false;
  end if;

  insert into public.post_likes (user_id, post_id) values (current_user_id, target_post_id)
  on conflict do nothing;
  select exists (
    select 1 from public.post_likes
    where user_id = current_user_id and post_id = target_post_id
  ) into liked_now;

  if liked_now then
    insert into public.interactions (user_id, post_id, interaction_type, tags, weight)
    select current_user_id, p.id, 'like', p.tags, 1 from public.posts p where p.id = target_post_id;
  end if;
  return liked_now;
end;
$$;

revoke all on function public.toggle_post_like(uuid) from public;
grant execute on function public.toggle_post_like(uuid) to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.users (id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(coalesce(new.email, ''), '@', 1), 'Home Cook'),
    new.email
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        email = excluded.email;
  return new;
end;
$$;

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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

insert into public.users (id, full_name, email)
select
  id,
  coalesce(raw_user_meta_data ->> 'full_name', split_part(coalesce(email, ''), '@', 1), 'Home Cook'),
  email
from auth.users
on conflict (id) do update
  set full_name = excluded.full_name,
      email = excluded.email;

alter table public.users enable row level security;
alter table public.posts enable row level security;
alter table public.interactions enable row level security;
alter table public.saved_collections enable row level security;
alter table public.post_likes enable row level security;
alter table public.comment_likes enable row level security;
alter table public.post_shares enable row level security;

drop policy if exists "Profiles are visible to signed-in users" on public.users;
create policy "Profiles are visible to signed-in users" on public.users
  for select to authenticated using (true);
drop policy if exists "Users update their own profile" on public.users;
create policy "Users update their own profile" on public.users
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
grant select, update on public.users to authenticated;

drop policy if exists "Recipes are visible to signed-in users" on public.posts;
create policy "Recipes are visible to signed-in users" on public.posts
  for select to authenticated using (true);
drop policy if exists "Users create their own recipes" on public.posts;
create policy "Users create their own recipes" on public.posts
  for insert to authenticated with check (auth.uid() = author_id);
drop policy if exists "Users edit their own recipes" on public.posts;
create policy "Users edit their own recipes" on public.posts
  for update to authenticated using (auth.uid() = author_id) with check (auth.uid() = author_id);
drop policy if exists "Users delete their own recipes" on public.posts;
create policy "Users delete their own recipes" on public.posts
  for delete to authenticated using (auth.uid() = author_id);

drop policy if exists "Comments and own interactions are visible" on public.interactions;
create policy "Comments and own interactions are visible" on public.interactions
  for select to authenticated using (interaction_type = 'comment' or auth.uid() = user_id);
drop policy if exists "Users create their own interactions" on public.interactions;
create policy "Users create their own interactions" on public.interactions
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users remove their own interactions" on public.interactions;
create policy "Users remove their own interactions" on public.interactions
  for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "Users manage their own collections" on public.saved_collections;
create policy "Users manage their own collections" on public.saved_collections
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users can view public collections" on public.saved_collections;
create policy "Users can view public collections" on public.saved_collections
  for select to authenticated using (is_public = true);

drop policy if exists "Users read their own likes" on public.post_likes;
create policy "Users read their own likes" on public.post_likes
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users manage their own likes" on public.post_likes;
create policy "Users manage their own likes" on public.post_likes
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Comment likes are visible to signed-in users" on public.comment_likes;
create policy "Comment likes are visible to signed-in users" on public.comment_likes
  for select to authenticated using (true);
drop policy if exists "Users manage their own comment likes" on public.comment_likes;
create policy "Users manage their own comment likes" on public.comment_likes
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users see their own shared recipes" on public.post_shares;
create policy "Users see their own shared recipes" on public.post_shares
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Signed-in users can view shared posts" on public.post_shares;
create policy "Signed-in users can view shared posts" on public.post_shares
  for select to authenticated using (true);
drop policy if exists "Users record their own recipe shares" on public.post_shares;
create policy "Users record their own recipe shares" on public.post_shares
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users remove their own recipe shares" on public.post_shares;
create policy "Users remove their own recipe shares" on public.post_shares
  for delete to authenticated using (auth.uid() = user_id);
grant select, insert, delete on public.post_shares to authenticated;

insert into storage.buckets (id, name, public)
values ('recipe_images', 'recipe_images', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Recipe images are public" on storage.objects;
create policy "Recipe images are public" on storage.objects
  for select using (bucket_id = 'recipe_images');
drop policy if exists "Signed-in users upload recipe images" on storage.objects;
create policy "Signed-in users upload recipe images" on storage.objects
  for insert to authenticated with check (bucket_id = 'recipe_images');
drop policy if exists "Signed-in users update recipe images" on storage.objects;
create policy "Signed-in users update recipe images" on storage.objects
  for update to authenticated using (bucket_id = 'recipe_images') with check (bucket_id = 'recipe_images');
drop policy if exists "Signed-in users delete recipe images" on storage.objects;
create policy "Signed-in users delete recipe images" on storage.objects
  for delete to authenticated using (bucket_id = 'recipe_images');

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

-- Enable Realtime for tables consumed with Supabase .stream().
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'posts'
  ) then
    alter publication supabase_realtime add table public.posts;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'interactions'
  ) then
    alter publication supabase_realtime add table public.interactions;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'saved_collections'
  ) then
    alter publication supabase_realtime add table public.saved_collections;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'comment_likes'
  ) then
    alter publication supabase_realtime add table public.comment_likes;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'post_shares'
  ) then
    alter publication supabase_realtime add table public.post_shares;
  end if;
end;
$$;
