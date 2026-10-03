-- Let users choose which saved collections appear on their public profile.
alter table public.saved_collections
  add column if not exists is_public boolean not null default false;

drop policy if exists "Users can view public collections" on public.saved_collections;
create policy "Users can view public collections" on public.saved_collections
  for select to authenticated using (is_public = true);

-- Shared post history is part of a user's public profile.
drop policy if exists "Signed-in users can view shared posts" on public.post_shares;
create policy "Signed-in users can view shared posts" on public.post_shares
  for select to authenticated using (true);

grant select on public.saved_collections to authenticated;
grant update (is_public) on public.saved_collections to authenticated;
grant select on public.post_shares to authenticated;

notify pgrst, 'reload schema';
