create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text not null,
  bio text default '',
  avatar_url text,
  soundcloud_url text,
  instagram_url text,
  youtube_url text,
  total_downloads integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.kits (
  id uuid primary key default gen_random_uuid(),
  producer_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  slug text unique not null,
  description text not null default '',
  genre_tags text[] not null default '{}',
  type text not null default 'Soundkit' check (type in ('Soundkit','Drumkit','Samples','SFX')),
  price numeric(10,2) not null default 0,
  cover_art_path text,
  archive_path text,
  archive_size_bytes bigint,
  format text not null default 'WAV / 24-BIT',
  sample_count integer not null default 0,
  license text not null default 'ROYALTY-FREE',
  download_count integer not null default 0,
  visibility text not null default 'public' check (visibility in ('public','private')),
  contents_index jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.demo_tracks (
  id uuid primary key default gen_random_uuid(),
  kit_id uuid not null references public.kits(id) on delete cascade,
  title text not null,
  audio_path text not null,
  duration_seconds integer,
  sort_order integer not null default 0
);

create table if not exists public.downloads (
  id uuid primary key default gen_random_uuid(),
  kit_id uuid not null references public.kits(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.kits add column if not exists type text not null default 'Soundkit';
alter table public.kits drop constraint if exists kits_type_check;
alter table public.kits add constraint kits_type_check check (type in ('Soundkit','Drumkit','Samples','SFX'));
alter table public.kits add column if not exists visibility text not null default 'public';
alter table public.kits add column if not exists contents_index jsonb not null default '[]'::jsonb;
alter table public.kits drop constraint if exists kits_visibility_check;
alter table public.kits add constraint kits_visibility_check check (visibility in ('public','private'));

create index if not exists kits_genre_tags_idx on public.kits using gin (genre_tags);
create index if not exists kits_producer_id_idx on public.kits (producer_id);
create index if not exists demo_tracks_kit_id_idx on public.demo_tracks (kit_id);
create index if not exists downloads_kit_id_idx on public.downloads (kit_id);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);
create table if not exists public.kit_likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  kit_id uuid not null references public.kits(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, kit_id)
);
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('follow','kit_like')),
  reference_id uuid not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists follows_following_idx on public.follows (following_id);
create index if not exists kit_likes_kit_idx on public.kit_likes (kit_id);
create index if not exists notifications_recipient_idx on public.notifications (recipient_id, is_read, created_at desc);

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare base_username text;
begin
  base_username := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'user_name', split_part(coalesce(new.email,'producer'),'@',1)), '[^a-zA-Z0-9_]', '', 'g'));
  if length(base_username) < 3 then base_username := 'producer'; end if;
  insert into public.profiles (id, username, display_name, avatar_url)
  values (new.id, left(base_username, 30), coalesce(new.raw_user_meta_data->>'full_name', new.email, 'Producer'), new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing;
  return new;
exception when unique_violation then
  insert into public.profiles (id, username, display_name, avatar_url) values (new.id, 'producer_' || substr(replace(new.id::text,'-',''),1,8), coalesce(new.email,'Producer'), new.raw_user_meta_data->>'avatar_url') on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.create_profile_for_new_user();

drop function if exists public.record_kit_download(uuid);
drop function if exists public.record_kit_download(uuid, uuid);
create or replace function public.record_kit_download(target_kit_id uuid, target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select producer_id into owner_id from public.kits where id = target_kit_id and visibility = 'public';
  if owner_id is null then raise exception 'Kit unavailable'; end if;
  insert into public.downloads (kit_id, user_id) values (target_kit_id, auth.uid());
  update public.kits set download_count = download_count + 1 where id = target_kit_id and visibility = 'public';
  update public.profiles set total_downloads = total_downloads + 1 where id = owner_id;
end;
$$;
revoke all on function public.record_kit_download(uuid, uuid) from public;
grant execute on function public.record_kit_download(uuid, uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.kits enable row level security;
alter table public.demo_tracks enable row level security;
alter table public.downloads enable row level security;
alter table public.follows enable row level security;
alter table public.kit_likes enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "public profiles are readable" on public.profiles;
drop policy if exists "users can create own profile" on public.profiles;
drop policy if exists "users can update own profile" on public.profiles;
drop policy if exists "owners can update kits" on public.kits;
drop policy if exists "owners can delete kits" on public.kits;
drop policy if exists "owners can update demos" on public.demo_tracks;
drop policy if exists "public kits are readable" on public.kits;
drop policy if exists "owners can read own kits" on public.kits;
drop policy if exists "public demos are readable" on public.demo_tracks;
drop policy if exists "authenticated users can create kits" on public.kits;
drop policy if exists "authenticated users can create demos" on public.demo_tracks;
drop policy if exists "anyone can record downloads" on public.downloads;
drop policy if exists "public follows readable" on public.follows;
drop policy if exists "users manage own follows" on public.follows;
drop policy if exists "public kit likes readable" on public.kit_likes;
drop policy if exists "users manage own kit likes" on public.kit_likes;
drop policy if exists "users read own notifications" on public.notifications;
drop policy if exists "users update own notifications" on public.notifications;

create policy "public profiles are readable" on public.profiles for select using (true);
create policy "users can create own profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy "users can update own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "public kits are readable" on public.kits for select using (visibility = 'public');
create policy "owners can read own kits" on public.kits for select to authenticated using (auth.uid() = producer_id);
create policy "public demos are readable" on public.demo_tracks for select using (true);
create policy "authenticated users can create kits" on public.kits for insert to authenticated with check (auth.uid() = producer_id);
create policy "authenticated users can create demos" on public.demo_tracks for insert to authenticated with check (exists (select 1 from public.kits where kits.id = kit_id and kits.producer_id = auth.uid()));
create policy "owners can update kits" on public.kits for update to authenticated using (auth.uid() = producer_id) with check (auth.uid() = producer_id);
create policy "owners can delete kits" on public.kits for delete to authenticated using (auth.uid() = producer_id);
create policy "owners can update demos" on public.demo_tracks for update to authenticated using (exists (select 1 from public.kits where kits.id = kit_id and kits.producer_id = auth.uid())) with check (exists (select 1 from public.kits where kits.id = kit_id and kits.producer_id = auth.uid()));
create policy "anyone can record downloads" on public.downloads for insert with check (true);
create policy "public follows readable" on public.follows for select using (true);
create policy "users manage own follows" on public.follows for all to authenticated using (auth.uid() = follower_id) with check (auth.uid() = follower_id and follower_id <> following_id);
create policy "public kit likes readable" on public.kit_likes for select using (true);
create policy "users manage own kit likes" on public.kit_likes for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users read own notifications" on public.notifications for select to authenticated using (auth.uid() = recipient_id);
create policy "users update own notifications" on public.notifications for update to authenticated using (auth.uid() = recipient_id) with check (auth.uid() = recipient_id);

create or replace function public.toggle_kit_like(target_kit_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare liked boolean;
declare owner_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select producer_id into owner_id from public.kits where id = target_kit_id and visibility = 'public';
  if owner_id is null then raise exception 'Kit unavailable'; end if;
  if exists(select 1 from public.kit_likes where user_id = auth.uid() and kit_id = target_kit_id) then
    delete from public.kit_likes where user_id = auth.uid() and kit_id = target_kit_id; liked := false;
  else
    insert into public.kit_likes(user_id, kit_id) values(auth.uid(), target_kit_id); liked := true;
    if owner_id <> auth.uid() then insert into public.notifications(recipient_id,actor_id,type,reference_id) values(owner_id,auth.uid(),'kit_like',target_kit_id); end if;
  end if;
  return liked;
end; $$;
revoke all on function public.toggle_kit_like(uuid) from public;
grant execute on function public.toggle_kit_like(uuid) to authenticated;

drop policy if exists "covers owner upload" on storage.objects;
drop policy if exists "demos owner upload" on storage.objects;
drop policy if exists "archives owner upload" on storage.objects;
drop policy if exists "owners can update files" on storage.objects;
drop policy if exists "owners can delete files" on storage.objects;
drop policy if exists "authenticated can create archive links" on storage.objects;
drop policy if exists "authenticated can read public archives" on storage.objects;
drop policy if exists "authenticated can read public demos" on storage.objects;
drop policy if exists "public can read covers" on storage.objects;

create policy "covers owner upload" on storage.objects for insert to authenticated with check (bucket_id = 'covers' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "demos owner upload" on storage.objects for insert to authenticated with check (bucket_id = 'demos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "archives owner upload" on storage.objects for insert to authenticated with check (bucket_id = 'archives' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owners can update files" on storage.objects for update to authenticated using ((storage.foldername(name))[1] = auth.uid()::text) with check ((storage.foldername(name))[1] = auth.uid()::text);
create policy "owners can delete files" on storage.objects for delete to authenticated using ((storage.foldername(name))[1] = auth.uid()::text);
create policy "authenticated can read public archives" on storage.objects for select to authenticated using (bucket_id = 'archives' and exists (select 1 from public.kits where kits.archive_path = storage.objects.name and kits.visibility = 'public'));
create policy "public can read public demos" on storage.objects for select using (bucket_id = 'demos' and exists (select 1 from public.demo_tracks join public.kits on kits.id = demo_tracks.kit_id where demo_tracks.audio_path = storage.objects.name and kits.visibility = 'public'));
create policy "public can read covers" on storage.objects for select using (bucket_id = 'covers');
create policy "authenticated can create archive links" on storage.objects for select to authenticated using (bucket_id = 'archives' and (storage.foldername(name))[1] = auth.uid()::text);
