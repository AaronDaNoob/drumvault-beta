begin;

create table if not exists public.kit_activity_daily (
  kit_id uuid not null references public.kits(id) on delete cascade,
  activity_date date not null default current_date,
  play_count integer not null default 0,
  saver_count integer not null default 0,
  viewer_ids uuid[] not null default '{}',
  primary key (kit_id, activity_date)
);

create table if not exists public.profile_view_daily (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  viewed_on date not null default current_date,
  created_at timestamptz not null default now(),
  primary key (profile_id, viewer_id, viewed_on),
  check (profile_id <> viewer_id)
);

create index if not exists kit_activity_daily_date_idx on public.kit_activity_daily (activity_date desc);
create index if not exists profile_view_daily_profile_idx on public.profile_view_daily (profile_id, viewed_on desc);

alter table public.kit_activity_daily enable row level security;
alter table public.profile_view_daily enable row level security;

create or replace function public.notification_allowed(target_user uuid, preference_key text)
returns boolean language sql stable security definer set search_path = public set row_security = off as $$
  select coalesce((select (to_jsonb(np)->>preference_key)::boolean from public.notification_preferences np where np.user_id = target_user), true);
$$;
revoke all on function public.notification_allowed(uuid,text) from public;
grant execute on function public.notification_allowed(uuid,text) to authenticated;

create or replace function public.insert_activity_notification(target_recipient uuid, target_actor uuid, target_type text, target_entity uuid, target_kit uuid default null, target_conversation uuid default null, target_message uuid default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if target_actor is null or target_recipient = target_actor then return; end if;
  if not public.notification_allowed(target_recipient, case when target_type in ('message_reply','message_reaction') then 'direct_messages' when target_type = 'kit_like' then 'kit_likes' when target_type = 'follow' then 'follows' else 'system' end) then return; end if;
  insert into public.notifications(recipient_id, actor_id, type, reference_id, entity_type, entity_id, kit_id, conversation_id, message_id, read_at)
  select target_recipient, target_actor, target_type, target_entity, target_type, target_entity, target_kit, target_conversation, target_message, null
  where not exists (select 1 from public.notifications n where n.recipient_id=target_recipient and n.actor_id=target_actor and n.type=target_type and n.entity_id=target_entity and n.created_at > now() - interval '1 day');
end;
$$;
revoke all on function public.insert_activity_notification(uuid,uuid,text,uuid,uuid,uuid,uuid) from public;
grant execute on function public.insert_activity_notification(uuid,uuid,text,uuid,uuid,uuid,uuid) to authenticated;

create or replace function public.notify_follow() returns trigger language plpgsql security definer set search_path=public as $$
begin perform public.insert_activity_notification(new.following_id,new.follower_id,'follow',new.following_id); return new; end; $$;
drop trigger if exists follows_notification on public.follows;
create trigger follows_notification after insert on public.follows for each row execute function public.notify_follow();

create or replace function public.notify_kit_like() returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid; begin select producer_id into owner_id from public.kits where id=new.kit_id; perform public.insert_activity_notification(owner_id,new.user_id,'kit_like',new.kit_id,new.kit_id); return new; end; $$;
drop trigger if exists kit_likes_notification on public.kit_likes;
create trigger kit_likes_notification after insert on public.kit_likes for each row execute function public.notify_kit_like();

create or replace function public.notify_message_activity() returns trigger language plpgsql security definer set search_path=public as $$
declare recipient_id uuid; begin select user_id into recipient_id from public.conversation_participants where conversation_id=new.conversation_id and user_id<>new.sender_id limit 1; if new.reply_to is not null then perform public.insert_activity_notification(recipient_id,new.sender_id,'message_reply',new.reply_to,null,new.conversation_id,new.id); end if; return new; end; $$;
drop trigger if exists messages_activity_notification on public.messages;
create trigger messages_activity_notification after insert on public.messages for each row execute function public.notify_message_activity();

create or replace function public.record_profile_view(target_profile uuid) returns void language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null or auth.uid()=target_profile then return; end if; insert into public.profile_view_daily(profile_id,viewer_id) values(target_profile,auth.uid()) on conflict do nothing; end; $$;
revoke all on function public.record_profile_view(uuid) from public;
grant execute on function public.record_profile_view(uuid) to authenticated;

create or replace function public.record_kit_play(target_kit uuid) returns void language plpgsql security definer set search_path=public as $$
begin insert into public.kit_activity_daily(kit_id,activity_date,play_count) values(target_kit,current_date,1) on conflict(kit_id,activity_date) do update set play_count=kit_activity_daily.play_count+1; end; $$;
revoke all on function public.record_kit_play(uuid) from public;
grant execute on function public.record_kit_play(uuid) to authenticated, anon;

commit;
notify pgrst, 'reload schema';
