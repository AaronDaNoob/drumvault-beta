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
  price numeric(10,2) not null default 0,
  cover_art_path text,
  archive_path text,
  archive_size_bytes bigint,
  format text not null default 'WAV / 24-BIT',
  sample_count integer not null default 0,
  license text not null default 'ROYALTY-FREE',
  download_count integer not null default 0,
  visibility text not null default 'public' check (visibility in ('public','private')),
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

alter table public.kits add column if not exists visibility text not null default 'public';
alter table public.kits drop constraint if exists kits_visibility_check;
alter table public.kits add constraint kits_visibility_check check (visibility in ('public','private'));

create index if not exists kits_genre_tags_idx on public.kits using gin (genre_tags);
create index if not exists kits_producer_id_idx on public.kits (producer_id);
create index if not exists demo_tracks_kit_id_idx on public.demo_tracks (kit_id);
create index if not exists downloads_kit_id_idx on public.downloads (kit_id);

alter table public.profiles enable row level security;
alter table public.kits enable row level security;
alter table public.demo_tracks enable row level security;
alter table public.downloads enable row level security;

drop policy if exists "public profiles are readable" on public.profiles;
drop policy if exists "users can create own profile" on public.profiles;
drop policy if exists "users can update own profile" on public.profiles;
drop policy if exists "owners can update kits" on public.kits;
drop policy if exists "owners can update demos" on public.demo_tracks;
drop policy if exists "public kits are readable" on public.kits;
drop policy if exists "public demos are readable" on public.demo_tracks;
drop policy if exists "authenticated users can create kits" on public.kits;
drop policy if exists "authenticated users can create demos" on public.demo_tracks;
drop policy if exists "anyone can record downloads" on public.downloads;

create policy "public profiles are readable" on public.profiles for select using (true);
create policy "users can create own profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy "users can update own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "public kits are readable" on public.kits for select using (true);
create policy "public demos are readable" on public.demo_tracks for select using (true);
create policy "authenticated users can create kits" on public.kits for insert to authenticated with check (auth.uid() = producer_id);
create policy "authenticated users can create demos" on public.demo_tracks for insert to authenticated with check (exists (select 1 from public.kits where kits.id = kit_id and kits.producer_id = auth.uid()));
create policy "owners can update kits" on public.kits for update to authenticated using (auth.uid() = producer_id) with check (auth.uid() = producer_id);
create policy "owners can update demos" on public.demo_tracks for update to authenticated using (exists (select 1 from public.kits where kits.id = kit_id and kits.producer_id = auth.uid())) with check (exists (select 1 from public.kits where kits.id = kit_id and kits.producer_id = auth.uid()));
create policy "anyone can record downloads" on public.downloads for insert with check (true);

drop policy if exists "covers owner upload" on storage.objects;
drop policy if exists "demos owner upload" on storage.objects;
drop policy if exists "archives owner upload" on storage.objects;
drop policy if exists "owners can update files" on storage.objects;
drop policy if exists "owners can delete files" on storage.objects;

create policy "covers owner upload" on storage.objects for insert to authenticated with check (bucket_id = 'covers' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "demos owner upload" on storage.objects for insert to authenticated with check (bucket_id = 'demos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "archives owner upload" on storage.objects for insert to authenticated with check (bucket_id = 'archives' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "owners can update files" on storage.objects for update to authenticated using ((storage.foldername(name))[1] = auth.uid()::text) with check ((storage.foldername(name))[1] = auth.uid()::text);
create policy "owners can delete files" on storage.objects for delete to authenticated using ((storage.foldername(name))[1] = auth.uid()::text);
