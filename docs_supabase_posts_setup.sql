-- NAGORI: 投稿機能（M-04 / M-06 / M-10）に必要なSupabase設定
-- Supabase ダッシュボード > SQL Editor で一度だけ実行してください。
-- 何度実行しても同じ結果になるように書いてあります。

-- 1. posts テーブルに不足カラムを追加
--    仕様書: prefecture は必須、location_name は任意（最大30文字）、comment は任意（最大140文字）
alter table public.posts add column if not exists prefecture    text not null default '';
alter table public.posts add column if not exists location_name text;

alter table public.posts drop constraint if exists posts_location_name_len;
alter table public.posts add constraint posts_location_name_len
  check (location_name is null or char_length(location_name) <= 30);

alter table public.posts drop constraint if exists posts_comment_len;
alter table public.posts add constraint posts_comment_len
  check (comment is null or char_length(comment) <= 140);

-- 2. posts のRLS（読み取りは全員OK、書き込みは本人のみ）
alter table public.posts enable row level security;

drop policy if exists "posts_select_all" on public.posts;
create policy "posts_select_all" on public.posts
  for select using (true);

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own" on public.posts
  for insert to authenticated with check (author_id = auth.uid());

drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own" on public.posts
  for delete to authenticated using (author_id = auth.uid());

-- 3. 投稿写真用のStorageバケット（avatarsと同じ構成）
insert into storage.buckets (id, name, public)
values ('posts', 'posts', true)
on conflict (id) do nothing;

drop policy if exists "post_images_read" on storage.objects;
create policy "post_images_read" on storage.objects
  for select using (bucket_id = 'posts');

drop policy if exists "post_images_upload_own" on storage.objects;
create policy "post_images_upload_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'posts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 4. users は全員が読める（投稿詳細で投稿者名・アイコンを表示するため）
--    ※すでに同等のポリシーがある場合はこのブロックを実行しなくてOKです。
alter table public.users enable row level security;

drop policy if exists "users_select_all" on public.users;
create policy "users_select_all" on public.users
  for select using (true);
