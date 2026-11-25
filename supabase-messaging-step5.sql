begin;

create index if not exists message_attachments_storage_path_idx on public.message_attachments (storage_path);

alter table public.message_attachments
  add column if not exists attachment_type text not null default 'file',
  add column if not exists metadata jsonb not null default '{}'::jsonb;

alter table public.messages
  add column if not exists share_type text,
  add column if not exists share_id uuid;

drop policy if exists "message attachments participants read" on storage.objects;
drop policy if exists "message attachments participants upload" on storage.objects;
drop policy if exists "message attachments owners delete" on storage.objects;

create policy "message attachments participants read"
on storage.objects for select to authenticated
using (
  bucket_id = 'message-attachments'
  and exists (
    select 1
    from public.message_attachments a
    join public.messages m on m.id = a.message_id
    where a.storage_path = storage.objects.name
      and public.is_conversation_participant(m.conversation_id)
  )
);

create policy "message attachments participants upload"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'message-attachments'
  and exists (
    select 1
    from public.messages m
    where m.sender_id = auth.uid()
      and m.id::text = (storage.foldername(name))[1]
      and public.is_conversation_participant(m.conversation_id)
  )
);

create policy "message attachments owners delete"
on storage.objects for delete to authenticated
using (
  bucket_id = 'message-attachments'
  and exists (
    select 1
    from public.message_attachments a
    join public.messages m on m.id = a.message_id
    where a.storage_path = storage.objects.name
      and m.sender_id = auth.uid()
  )
);

commit;

notify pgrst, 'reload schema';
