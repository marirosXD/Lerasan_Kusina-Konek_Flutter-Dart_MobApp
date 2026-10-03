-- Apply in Supabase Dashboard > SQL Editor to store ordered recipe photo galleries.

alter table public.posts
  add column if not exists image_urls jsonb not null default '[]'::jsonb,
  add column if not exists client_request_id text;

create unique index if not exists posts_author_client_request_idx
  on public.posts (author_id, client_request_id)
  where client_request_id is not null;

update public.posts
set image_urls = jsonb_build_array(image_url)
where image_url is not null
  and image_url <> ''
  and (image_urls is null or image_urls = '[]'::jsonb);

notify pgrst, 'reload schema';
