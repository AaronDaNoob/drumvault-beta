-- Run as an authenticated user in Supabase SQL Editor only after replacing the UUIDs.
-- Find IDs with: select id, username from public.profiles order by created_at desc limit 10;
-- Replace both UUIDs below before running.
with seed as (
  select '00000000-0000-0000-0000-000000000001'::uuid as user_a,
         '00000000-0000-0000-0000-000000000002'::uuid as user_b
), conversation as (
  insert into public.conversations (created_by)
  select user_a from seed
  returning id
)
insert into public.conversation_participants (conversation_id, user_id)
select conversation.id, seed.user_a from conversation cross join seed
union all
select conversation.id, seed.user_b from conversation cross join seed;
