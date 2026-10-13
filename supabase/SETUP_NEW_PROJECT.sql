-- Run once on the NEW Shia Family Messenger Supabase project only.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check(username ~ '^[a-z0-9_]{3,30}$'),
 display_name text not null check(length(display_name) between 1 and 80),
 created_at timestamptz not null default now()
);
create table if not exists public.conversations (
 id uuid primary key default gen_random_uuid(),
 kind text not null default 'private' check(kind in ('private','group','channel')),
 title text, created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.conversation_members (
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'member' check(role in ('owner','admin','member')),
 primary key(conversation_id,user_id)
);
create table if not exists public.messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 sender_id uuid not null references auth.users(id),
 body text check(length(body)<=10000),
 media_path text,
 media_type text check(media_type in ('image','video','audio','file')),
 created_at timestamptz not null default now(),
 constraint message_content check(nullif(btrim(coalesce(body,'')),'') is not null or media_path is not null)
);
create index if not exists messages_conversation_time on public.messages(conversation_id,created_at);
create index if not exists members_user on public.conversation_members(user_id);
create or replace function public.is_conversation_member(cid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.conversation_members where conversation_id=cid and user_id=(select auth.uid()));
$$;
create or replace function public.is_conversation_admin(cid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.conversation_members where conversation_id=cid and user_id=(select auth.uid()) and role in ('owner','admin'));
$$;
create or replace function public.add_conversation_owner() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.conversation_members(conversation_id,user_id,role) values(new.id,new.created_by,'owner');
 return new;
end $$;
drop trigger if exists conversation_owner on public.conversations;
create trigger conversation_owner after insert on public.conversations for each row execute function public.add_conversation_owner();
alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
create policy profiles_read on public.profiles for select to authenticated using(true);
create policy profiles_insert on public.profiles for insert to authenticated with check(id=auth.uid());
create policy profiles_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy conversations_read on public.conversations for select to authenticated using(public.is_conversation_member(id));
create policy conversations_create on public.conversations for insert to authenticated with check(created_by=auth.uid());
create policy members_read on public.conversation_members for select to authenticated using(public.is_conversation_member(conversation_id));
create policy messages_read on public.messages for select to authenticated using(public.is_conversation_member(conversation_id));
create policy messages_send on public.messages for insert to authenticated with check(
 sender_id=auth.uid() and public.is_conversation_member(conversation_id)
 and exists(select 1 from public.conversations c where c.id=conversation_id and (c.kind <> 'channel' or public.is_conversation_admin(conversation_id)))
);
create or replace function public.start_private_conversation(peer_username text) returns uuid
language plpgsql security definer set search_path='' as $$
declare peer uuid; cid uuid; caller uuid := auth.uid();
begin
 if caller is null then raise exception 'Sign in required'; end if;
 select id into peer from public.profiles where username=lower(trim(peer_username));
 if peer is null or peer=caller then raise exception 'Invalid recipient'; end if;
 insert into public.conversations(kind,created_by,title) values('private',caller,'محادثة خاصة') returning id into cid;
 insert into public.conversation_members(conversation_id,user_id,role) values(cid,peer,'member');
 return cid;
end $$;
revoke all on function public.start_private_conversation(text) from public;
grant execute on function public.start_private_conversation(text) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit) values('chat-media','chat-media',false,52428800) on conflict(id) do nothing;
drop policy if exists chat_media_read on storage.objects;
drop policy if exists chat_media_upload on storage.objects;
create policy chat_media_read on storage.objects for select to authenticated using(
 bucket_id='chat-media' and split_part(name,'/',1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 and public.is_conversation_member(split_part(name,'/',1)::uuid)
);
create policy chat_media_upload on storage.objects for insert to authenticated with check(
 bucket_id='chat-media' and split_part(name,'/',1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 and split_part(name,'/',2)=auth.uid()::text
 and public.is_conversation_member(split_part(name,'/',1)::uuid)
);
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then
  alter publication supabase_realtime add table public.messages;
 end if;
end $$;
