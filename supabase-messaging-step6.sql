begin;

create table if not exists public.conversation_mutes (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  muted_until timestamptz,
  created_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.message_reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (reason in ('spam', 'harassment', 'hate', 'sexual', 'violence', 'self_harm', 'illegal', 'other')),
  details text not null default '' check (char_length(details) <= 2000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  unique (message_id, reporter_id)
);

create index if not exists conversation_mutes_user_idx on public.conversation_mutes (user_id, conversation_id);
create index if not exists message_reports_status_idx on public.message_reports (status, created_at desc);

alter table public.conversation_mutes enable row level security;
alter table public.message_reports enable row level security;

drop policy if exists "users manage own conversation mutes" on public.conversation_mutes;
create policy "users manage own conversation mutes" on public.conversation_mutes for all to authenticated
using (user_id = auth.uid() and public.is_conversation_participant(conversation_id))
with check (user_id = auth.uid() and public.is_conversation_participant(conversation_id));

drop policy if exists "participants report messages" on public.message_reports;
create policy "participants report messages" on public.message_reports for insert to authenticated
with check (
  reporter_id = auth.uid()
  and exists (select 1 from public.messages m where m.id = message_id and public.is_conversation_participant(m.conversation_id))
);

drop policy if exists "reporters read own reports" on public.message_reports;
create policy "reporters read own reports" on public.message_reports for select to authenticated using (reporter_id = auth.uid());

create or replace function public.can_message_user(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select auth.uid() is not null
    and auth.uid() <> target_user_id
    and not exists (
      select 1 from public.blocks
      where (blocker_id = auth.uid() and blocked_id = target_user_id)
         or (blocker_id = target_user_id and blocked_id = auth.uid())
    );
$$;
revoke all on function public.can_message_user(uuid) from public;
grant execute on function public.can_message_user(uuid) to authenticated;

create or replace function public.enforce_message_safety()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient_id uuid;
  recent_count integer;
begin
  if char_length(new.body) > 10000 then raise exception 'Message is too long'; end if;
  if new.deleted_at is null and (new.body is null or btrim(new.body) = '') then raise exception 'Message cannot be empty'; end if;
  if not exists (select 1 from public.conversation_participants where conversation_id = new.conversation_id and user_id = new.sender_id) then raise exception 'Sender is not a conversation participant'; end if;
  select cp.user_id into recipient_id from public.conversation_participants cp where cp.conversation_id = new.conversation_id and cp.user_id <> new.sender_id limit 1;
  if recipient_id is not null and not public.can_message_user(recipient_id) then raise exception 'Messaging is unavailable'; end if;
  select count(*) into recent_count from public.messages where sender_id = new.sender_id and created_at > now() - interval '1 minute';
  if recent_count >= 30 then raise exception 'Message rate limit exceeded'; end if;
  return new;
end;
$$;

drop trigger if exists messages_enforce_safety on public.messages;
create trigger messages_enforce_safety before insert or update on public.messages for each row execute function public.enforce_message_safety();

commit;
notify pgrst, 'reload schema';
