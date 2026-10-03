-- Apply in Supabase Dashboard > SQL Editor to upgrade an existing project.
-- This aligns social tables with the Flutter app and repairs the like RPC.

create table if not exists public.interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  interaction_type text not null default 'comment',
  comment_text text,
  user_name text,
  tags jsonb not null default '[]'::jsonb,
  weight double precision not null default 1,
  created_at timestamptz not null default now()
);

alter table public.interactions
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists interaction_type text not null default 'comment',
  add column if not exists comment_text text,
  add column if not exists user_name text,
  add column if not exists tags jsonb not null default '[]'::jsonb,
  add column if not exists weight double precision not null default 1,
  add column if not exists created_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.interactions'::regclass and contype = 'p'
  ) then
    alter table public.interactions add constraint interactions_pkey primary key (id);
  end if;
end;
$$;

create table if not exists public.post_likes (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create index if not exists interactions_user_id_idx on public.interactions (user_id);
create index if not exists interactions_post_id_idx on public.interactions (post_id);
create index if not exists post_likes_post_id_idx on public.post_likes (post_id);

alter table public.interactions enable row level security;
alter table public.post_likes enable row level security;

drop policy if exists "Comments and own interactions are visible" on public.interactions;
create policy "Comments and own interactions are visible" on public.interactions
  for select to authenticated using (interaction_type = 'comment' or auth.uid() = user_id);
drop policy if exists "Users create their own interactions" on public.interactions;
create policy "Users create their own interactions" on public.interactions
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users remove their own interactions" on public.interactions;
create policy "Users remove their own interactions" on public.interactions
  for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "Users read their own likes" on public.post_likes;
create policy "Users read their own likes" on public.post_likes
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users manage their own likes" on public.post_likes;
create policy "Users manage their own likes" on public.post_likes
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select, insert, delete on public.interactions to authenticated;
grant select, insert, delete on public.post_likes to authenticated;

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

  insert into public.post_likes (user_id, post_id)
  values (current_user_id, target_post_id)
  on conflict do nothing;

  select exists (
    select 1 from public.post_likes
    where user_id = current_user_id and post_id = target_post_id
  ) into liked_now;

  if liked_now then
    insert into public.interactions (user_id, post_id, interaction_type, tags, weight)
    select current_user_id, p.id, 'like', p.tags, 1
    from public.posts p where p.id = target_post_id;
  end if;
  return liked_now;
end;
$$;

revoke all on function public.toggle_post_like(uuid) from public;
grant execute on function public.toggle_post_like(uuid) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'interactions'
  ) then
    alter publication supabase_realtime add table public.interactions;
  end if;
end;
$$;

notify pgrst, 'reload schema';
