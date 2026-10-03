-- Apply in Supabase Dashboard > SQL Editor when upgrading an existing project.
-- New installations can use ../schema.sql instead.

alter table public.posts
  add column if not exists author_name text not null default 'Home Cook',
  add column if not exists cooking_notes text not null default '',
  add column if not exists prep_time_value integer not null default 0,
  add column if not exists prep_time_unit text not null default 'min',
  add column if not exists servings integer not null default 1,
  add column if not exists region text not null default '',
  add column if not exists difficulty text not null default 'Easy';

update public.posts
set prep_time_value = prep_time_minutes
where prep_time_value = 0 and prep_time_minutes > 0;

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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- The trigger only handles future accounts. Add profile rows for accounts
-- that were already registered before the trigger was installed.
insert into public.users (id, full_name, email)
select
  id,
  coalesce(raw_user_meta_data ->> 'full_name', split_part(coalesce(email, ''), '@', 1), 'Home Cook'),
  email
from auth.users
on conflict (id) do update
  set full_name = excluded.full_name,
      email = excluded.email;

notify pgrst, 'reload schema';
