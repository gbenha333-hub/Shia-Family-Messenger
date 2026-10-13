-- Initial messaging schema: apply only to the future independent Supabase project.
create extension if not exists pgcrypto;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null check (username ~ '^[a-z0-9_]{3,30}$'),
 display_name text not null check (char_length(display_name) between 1 and 80),
 avatar_path text, bio text default '', created_at timestamptz not null default now()
);
create table public.conversations (
 id uuid primary key default gen_random_uuid(),
 kind text not null check (kind in ('private','group','channel')),
 title text, created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create table public.conversation_members (
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'member' check (role in ('owner','admin','member')),
 joined_at timestamptz not null default now(),
 primary key(conversation_id,user_id)
);
create table public.messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 sender_id uuid not null references auth.users(id),
 body text check (char_length(body) <= 10000),
 media_path text,
 media_type text check (media_type in ('image','video','audio','file')),
 created_at timestamptz not null default now(),
 deleted_at timestamptz,
 constraint message_has_content check (nullif(btrim(coalesce(body,'')),'') is not null or media_path is not null)
);
create index messages_by_conversation on public.messages(conversation_id,created_at desc);
create index members_by_user on public.conversation_members(user_id);
create function public.is_conversation_member(cid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.conversation_members cm where cm.conversation_id=cid and cm.user_id=(select auth.uid()));
$$;
revoke all on function public.is_conversation_member(uuid) from public;
grant execute on function public.is_conversation_member(uuid) to authenticated;
create function public.is_conversation_admin(cid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.conversation_members cm where cm.conversation_id=cid and cm.user_id=(select auth.uid()) and cm.role in ('owner','admin'));
$$;
revoke all on function public.is_conversation_admin(uuid) from public;
grant execute on function public.is_conversation_admin(uuid) to authenticated;
create function public.add_conversation_owner() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 insert into public.conversation_members(conversation_id,user_id,role) values(new.id,new.created_by,'owner');
 return new;
end $$;
create trigger conversation_owner after insert on public.conversations for each row execute function public.add_conversation_owner();
alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
create policy profiles_read on public.profiles for select to authenticated using (true);
create policy profiles_insert on public.profiles for insert to authenticated with check (id=(select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated using (id=(select auth.uid())) with check (id=(select auth.uid()));
create policy conversations_read on public.conversations for select to authenticated using (public.is_conversation_member(id));
create policy conversations_create on public.conversations for insert to authenticated with check (created_by=(select auth.uid()));
create policy conversations_update on public.conversations for update to authenticated using (public.is_conversation_admin(id)) with check (public.is_conversation_admin(id));
create policy members_read on public.conversation_members for select to authenticated using (public.is_conversation_member(conversation_id));
create policy members_insert on public.conversation_members for insert to authenticated with check (public.is_conversation_admin(conversation_id));
create policy members_delete on public.conversation_members for delete to authenticated using (public.is_conversation_admin(conversation_id) or user_id=(select auth.uid()));
create policy messages_read on public.messages for select to authenticated using (public.is_conversation_member(conversation_id));
create policy messages_send on public.messages for insert to authenticated with check (sender_id=(select auth.uid()) and public.is_conversation_member(conversation_id) and (not exists(select 1 from public.conversations c where c.id=conversation_id and c.kind='channel') or public.is_conversation_admin(conversation_id)));
create policy messages_edit on public.messages for update to authenticated using (sender_id=(select auth.uid()) and public.is_conversation_member(conversation_id)) with check (sender_id=(select auth.uid()) and public.is_conversation_member(conversation_id));
insert into storage.buckets (id,name,public,file_size_limit) values ('chat-media','chat-media',false,52428800) on conflict(id) do nothing;
create policy media_read on storage.objects for select to authenticated using (
 bucket_id='chat-media' and public.is_conversation_member((split_part(name,'/',1))::uuid)
);
create policy media_upload on storage.objects for insert to authenticated with check (
 bucket_id='chat-media' and split_part(name,'/',2)=(select auth.uid())::text and public.is_conversation_member((split_part(name,'/',1))::uuid)
);
-- After deploying, enable postgres_changes Realtime for public.messages.
