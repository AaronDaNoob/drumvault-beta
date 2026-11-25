begin;

alter table public.profiles
  add column if not exists presence_status text not null default 'offline',
  add column if not exists last_seen_at timestamptz;

alter table public.profiles
  drop constraint if exists profiles_presence_status_check;
alter table public.profiles
  add constraint profiles_presence_status_check
  check (presence_status in ('online', 'idle', 'offline'));

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  last_read_at timestamptz,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '',
  reply_to uuid references public.messages(id) on delete set null,
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  check (char_length(body) <= 10000),
  check (body <> '' or deleted_at is not null)
);

create table if not exists public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null check (char_length(reaction) between 1 and 32),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, reaction)
);

create table if not exists public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  storage_path text not null,
  file_name text not null,
  content_type text,
  byte_size bigint check (byte_size is null or byte_size >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.notifications
  add column if not exists entity_type text,
  add column if not exists entity_id uuid,
  add column if not exists conversation_id uuid references public.conversations(id) on delete cascade,
  add column if not exists message_id uuid references public.messages(id) on delete cascade,
  add column if not exists kit_id uuid references public.kits(id) on delete cascade,
  add column if not exists read_at timestamptz;

alter table public.notifications
  alter column actor_id drop not null,
  alter column reference_id drop not null;

do $$
declare constraint_name text;
begin
  for constraint_name in
    select conname
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%type%'
  loop
    execute format('alter table public.notifications drop constraint %I', constraint_name);
  end loop;
end;
$$;
alter table public.notifications
  add constraint notifications_type_check
  check (type in ('follow', 'kit_like', 'message', 'reaction', 'mention', 'system'));

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  direct_messages boolean not null default true,
  reactions boolean not null default true,
  follows boolean not null default true,
  kit_likes boolean not null default true,
  system boolean not null default true,
  updated_at timestamptz not null default now()
);

create or replace function public.is_conversation_participant(target_conversation_id uuid, target_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1 from public.conversation_participants
    where conversation_id = target_conversation_id and user_id = target_user_id
  );
$$;

revoke all on function public.is_conversation_participant(uuid, uuid) from public;
grant execute on function public.is_conversation_participant(uuid, uuid) to authenticated;

create or replace function public.touch_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations set updated_at = new.created_at where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation
after insert on public.messages
for each row execute function public.touch_conversation();

create index if not exists conversations_updated_at_idx on public.conversations (updated_at desc);
create index if not exists conversation_participants_user_idx on public.conversation_participants (user_id, conversation_id);
create index if not exists messages_conversation_created_idx on public.messages (conversation_id, created_at desc, id desc);
create index if not exists messages_sender_created_idx on public.messages (sender_id, created_at desc);
create index if not exists message_reactions_message_idx on public.message_reactions (message_id);
create index if not exists message_attachments_message_idx on public.message_attachments (message_id);
create index if not exists blocks_blocked_idx on public.blocks (blocked_id);
create index if not exists notifications_recipient_read_created_idx on public.notifications (recipient_id, read_at, created_at desc);
create index if not exists notifications_entity_idx on public.notifications (entity_type, entity_id);
create index if not exists notifications_conversation_idx on public.notifications (conversation_id, created_at desc);
create index if not exists profiles_presence_idx on public.profiles (presence_status, last_seen_at desc);

alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.message_reactions enable row level security;
alter table public.message_attachments enable row level security;
alter table public.blocks enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_preferences enable row level security;

drop policy if exists "participants read conversations" on public.conversations;
drop policy if exists "authenticated create conversations" on public.conversations;
drop policy if exists "participants update conversations" on public.conversations;
create policy "participants read conversations" on public.conversations for select to authenticated using (public.is_conversation_participant(id));
create policy "authenticated create conversations" on public.conversations for insert to authenticated with check (created_by is null or created_by = auth.uid());
create policy "participants update conversations" on public.conversations for update to authenticated using (public.is_conversation_participant(id)) with check (public.is_conversation_participant(id));

drop policy if exists "participants read participant rows" on public.conversation_participants;
drop policy if exists "users join conversations" on public.conversation_participants;
drop policy if exists "participants update read state" on public.conversation_participants;
drop policy if exists "users leave conversations" on public.conversation_participants;
create policy "participants read participant rows" on public.conversation_participants for select to authenticated using (public.is_conversation_participant(conversation_id));
create policy "users join conversations" on public.conversation_participants for insert to authenticated with check (user_id = auth.uid() or public.is_conversation_participant(conversation_id));
create policy "participants update read state" on public.conversation_participants for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "users leave conversations" on public.conversation_participants for delete to authenticated using (user_id = auth.uid());

drop policy if exists "participants read messages" on public.messages;
drop policy if exists "participants send messages" on public.messages;
drop policy if exists "senders edit messages" on public.messages;
drop policy if exists "senders delete messages" on public.messages;
create policy "participants read messages" on public.messages for select to authenticated using (public.is_conversation_participant(conversation_id));
create policy "participants send messages" on public.messages for insert to authenticated with check (sender_id = auth.uid() and public.is_conversation_participant(conversation_id));
create policy "senders edit messages" on public.messages for update to authenticated using (sender_id = auth.uid() and public.is_conversation_participant(conversation_id)) with check (sender_id = auth.uid() and public.is_conversation_participant(conversation_id));
create policy "senders delete messages" on public.messages for delete to authenticated using (sender_id = auth.uid() and public.is_conversation_participant(conversation_id));

drop policy if exists "participants read reactions" on public.message_reactions;
drop policy if exists "users manage own reactions" on public.message_reactions;
create policy "participants read reactions" on public.message_reactions for select to authenticated using (exists (select 1 from public.messages m where m.id = message_id and public.is_conversation_participant(m.conversation_id)));
create policy "users manage own reactions" on public.message_reactions for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid() and exists (select 1 from public.messages m where m.id = message_id and public.is_conversation_participant(m.conversation_id)));

drop policy if exists "participants read attachments" on public.message_attachments;
drop policy if exists "senders manage attachments" on public.message_attachments;
create policy "participants read attachments" on public.message_attachments for select to authenticated using (exists (select 1 from public.messages m where m.id = message_id and public.is_conversation_participant(m.conversation_id)));
create policy "senders manage attachments" on public.message_attachments for all to authenticated using (exists (select 1 from public.messages m where m.id = message_id and m.sender_id = auth.uid())) with check (exists (select 1 from public.messages m where m.id = message_id and m.sender_id = auth.uid()));

drop policy if exists "users read own blocks" on public.blocks;
drop policy if exists "users manage own blocks" on public.blocks;
create policy "users read own blocks" on public.blocks for select to authenticated using (blocker_id = auth.uid());
create policy "users manage own blocks" on public.blocks for all to authenticated using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

drop policy if exists "users read own notifications" on public.notifications;
drop policy if exists "users update own notifications" on public.notifications;
create policy "users read own notifications" on public.notifications for select to authenticated using (recipient_id = auth.uid());
create policy "users update own notifications" on public.notifications for update to authenticated using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

drop policy if exists "users read own notification preferences" on public.notification_preferences;
drop policy if exists "users manage own notification preferences" on public.notification_preferences;
create policy "users read own notification preferences" on public.notification_preferences for select to authenticated using (user_id = auth.uid());
create policy "users manage own notification preferences" on public.notification_preferences for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

commit;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;

notify pgrst, 'reload schema';
