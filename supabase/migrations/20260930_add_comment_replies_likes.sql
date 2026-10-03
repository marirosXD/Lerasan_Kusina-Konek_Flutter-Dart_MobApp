-- Apply in Supabase Dashboard > SQL Editor to add replies and likes to comments.

alter table public.interactions
  add column if not exists parent_comment_id uuid
  references public.interactions(id) on delete cascade;

create table if not exists public.comment_likes (
  comment_id uuid not null references public.interactions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

create index if not exists comment_likes_comment_id_idx
  on public.comment_likes (comment_id);

alter table public.comment_likes enable row level security;

drop policy if exists "Comment likes are visible to signed-in users" on public.comment_likes;
create policy "Comment likes are visible to signed-in users" on public.comment_likes
  for select to authenticated using (true);

drop policy if exists "Users manage their own comment likes" on public.comment_likes;
create policy "Users manage their own comment likes" on public.comment_likes
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select, insert, delete on public.comment_likes to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'interactions'
  ) then
    alter publication supabase_realtime add table public.interactions;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'comment_likes'
  ) then
    alter publication supabase_realtime add table public.comment_likes;
  end if;
end;
$$;

notify pgrst, 'reload schema';
