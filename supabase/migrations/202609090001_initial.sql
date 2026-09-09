create extension if not exists pgcrypto;
create schema if not exists private;

create type public.member_role as enum ('principal','staff');
create type public.member_status as enum ('active','inactive');
create type public.tx_kind as enum ('income','expense','transfer');
create type public.tx_status as enum ('posted','void');
create type public.bill_status as enum ('unpaid','partial','paid','void');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  full_name text not null,
  is_super_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  npsn text,
  address text,
  city text,
  principal_name text,
  treasurer_name text,
  academic_year text not null default '2026/2027',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.school_members (
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.member_role not null,
  status public.member_status not null default 'active',
  created_at timestamptz not null default now(),
  primary key (school_id,user_id)
);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  token_hash text unique not null,
  expires_at timestamptz not null,
  invited_by uuid not null references public.profiles(id),
  accepted_by uuid references public.profiles(id),
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.classes (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  name text not null, active boolean not null default true, created_at timestamptz not null default now(),
  unique(school_id,name)
);

create table public.students (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid references public.classes(id), nis text not null, nisn text, name text not null,
  guardian_name text, guardian_phone text, status text not null default 'active', discount numeric(14,2) not null default 0,
  created_at timestamptz not null default now(), unique(school_id,nis)
);

create table public.cash_accounts (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  name text not null, type text not null default 'cash', opening_balance numeric(16,2) not null default 0,
  active boolean not null default true, created_at timestamptz not null default now(), unique(school_id,name)
);

create table public.activities (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  code text not null, name text not null, funding_source text, budget numeric(16,2) not null default 0,
  created_at timestamptz not null default now(), unique(school_id,code)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  number text not null, tx_date date not null default current_date, kind public.tx_kind not null,
  cash_account_id uuid references public.cash_accounts(id), target_cash_account_id uuid references public.cash_accounts(id),
  activity_id uuid references public.activities(id), student_id uuid references public.students(id),
  category text not null, description text not null, amount numeric(16,2) not null check(amount > 0),
  proof_path text, status public.tx_status not null default 'posted', void_reason text,
  created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(school_id,number)
);

create table public.bills (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id), title text not null, period text,
  due_date date, amount numeric(16,2) not null check(amount > 0), paid_amount numeric(16,2) not null default 0,
  status public.bill_status not null default 'unpaid', created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(), check(paid_amount >= 0 and paid_amount <= amount)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references public.schools(id) on delete cascade,
  receipt_number text not null, student_id uuid not null references public.students(id),
  cash_account_id uuid not null references public.cash_accounts(id), payment_date date not null default current_date,
  amount numeric(16,2) not null check(amount > 0), method text not null default 'Tunai', notes text,
  created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), unique(school_id,receipt_number)
);

create table public.payment_allocations (
  id uuid primary key default gen_random_uuid(), payment_id uuid not null references public.payments(id) on delete cascade,
  bill_id uuid not null references public.bills(id), amount numeric(16,2) not null check(amount > 0), unique(payment_id,bill_id)
);

create table public.audit_logs (
  id bigint generated always as identity primary key, school_id uuid references public.schools(id) on delete cascade,
  user_id uuid references public.profiles(id), action text not null, entity text not null, entity_id text,
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table public.subscriptions (
  school_id uuid primary key references public.schools(id) on delete cascade, plan text not null default 'trial',
  status text not null default 'trial', starts_at timestamptz not null default now(), ends_at timestamptz,
  price numeric(16,2) not null default 0
);

create table public.usage_metrics (
  school_id uuid primary key references public.schools(id) on delete cascade,
  students_count integer not null default 0, transactions_count integer not null default 0,
  reports_count integer not null default 0, storage_bytes bigint not null default 0,
  last_active_at timestamptz, updated_at timestamptz not null default now()
);

create index on public.school_members(user_id,status);
create index on public.students(school_id,class_id,status);
create index on public.transactions(school_id,tx_date,status);
create index on public.bills(school_id,student_id,status);
create index on public.payments(school_id,student_id,payment_date);
create index on public.audit_logs(school_id,created_at desc);

create or replace function private.is_member(target uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.school_members where school_id=target and user_id=(select auth.uid()) and status='active')
$$;
create or replace function private.is_principal(target uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.school_members where school_id=target and user_id=(select auth.uid()) and role='principal' and status='active')
$$;
create or replace function private.is_super() returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.profiles where id=(select auth.uid()) and is_super_admin=true)
$$;
revoke all on all functions in schema private from public;
grant usage on schema private to authenticated;
grant execute on function private.is_member(uuid), private.is_principal(uuid), private.is_super() to authenticated;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.profiles(id,username,full_name)
  values(new.id, coalesce(nullif(new.raw_user_meta_data->>'username',''),split_part(new.email,'@',1)) || '-' || substr(new.id::text,1,6), coalesce(nullif(new.raw_user_meta_data->>'full_name',''),split_part(new.email,'@',1)));
  return new;
end $$;
revoke all on function public.handle_new_user() from public,anon,authenticated;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.create_school(school_name text, school_npsn text, school_address text, school_city text, year_label text)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
  if (select auth.uid()) is null then raise exception 'Login diperlukan'; end if;
  insert into public.schools(name,npsn,address,city,academic_year,created_by)
  values(school_name,school_npsn,school_address,school_city,year_label,(select auth.uid())) returning id into sid;
  insert into public.school_members(school_id,user_id,role) values(sid,(select auth.uid()),'principal');
  insert into public.cash_accounts(school_id,name,type) values(sid,'Kas Tunai','cash');
  insert into public.subscriptions(school_id) values(sid);
  insert into public.usage_metrics(school_id) values(sid);
  return sid;
end $$;
revoke all on function public.create_school(text,text,text,text,text) from public,anon;
grant execute on function public.create_school(text,text,text,text,text) to authenticated;

create or replace function public.create_invitation(target_school uuid)
returns text language plpgsql security definer set search_path='' as $$
declare raw_token text := encode(gen_random_bytes(24),'hex');
begin
  if not private.is_principal(target_school) then raise exception 'Akses ditolak'; end if;
  insert into public.invitations(school_id,token_hash,expires_at,invited_by)
  values(target_school,encode(digest(raw_token,'sha256'),'hex'),now()+interval '7 days',(select auth.uid()));
  return raw_token;
end $$;
revoke all on function public.create_invitation(uuid) from public,anon;
grant execute on function public.create_invitation(uuid) to authenticated;

create or replace function public.accept_invitation(raw_token text)
returns uuid language plpgsql security definer set search_path='' as $$
declare inv public.invitations; hashed text := encode(digest(raw_token,'sha256'),'hex');
begin
  if (select auth.uid()) is null then raise exception 'Login diperlukan'; end if;
  select * into inv from public.invitations where token_hash=hashed and accepted_at is null and revoked_at is null and expires_at>now() for update;
  if inv.id is null then raise exception 'Undangan tidak valid atau sudah berakhir'; end if;
  insert into public.school_members(school_id,user_id,role) values(inv.school_id,(select auth.uid()),'staff') on conflict do nothing;
  update public.invitations set accepted_by=(select auth.uid()),accepted_at=now() where id=inv.id;
  return inv.school_id;
end $$;
revoke all on function public.accept_invitation(text) from public,anon;
grant execute on function public.accept_invitation(text) to authenticated;

alter table public.profiles enable row level security;
alter table public.schools enable row level security;
alter table public.school_members enable row level security;
alter table public.invitations enable row level security;
alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.cash_accounts enable row level security;
alter table public.activities enable row level security;
alter table public.transactions enable row level security;
alter table public.bills enable row level security;
alter table public.payments enable row level security;
alter table public.payment_allocations enable row level security;
alter table public.audit_logs enable row level security;
alter table public.subscriptions enable row level security;
alter table public.usage_metrics enable row level security;

create policy profiles_self on public.profiles for select to authenticated using(id=(select auth.uid()) or private.is_super() or exists(select 1 from public.school_members me join public.school_members them on them.school_id=me.school_id where me.user_id=(select auth.uid()) and me.status='active' and them.user_id=profiles.id));
create policy profiles_update_self on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()) and is_super_admin=false);
create policy schools_read on public.schools for select to authenticated using(private.is_member(id) or private.is_super());
create policy schools_update on public.schools for update to authenticated using(private.is_principal(id)) with check(private.is_principal(id));
create policy members_read on public.school_members for select to authenticated using(private.is_member(school_id) or private.is_super());
create policy members_update on public.school_members for update to authenticated using(private.is_principal(school_id)) with check(private.is_principal(school_id));
create policy invites_read on public.invitations for select to authenticated using(private.is_principal(school_id));
create policy invites_update on public.invitations for update to authenticated using(private.is_principal(school_id)) with check(private.is_principal(school_id));

do $$ declare t text; begin
  foreach t in array array['classes','students','cash_accounts','activities','transactions','bills','payments'] loop
    execute format('create policy %I on public.%I for select to authenticated using(private.is_member(school_id))',t||'_read',t);
    execute format('create policy %I on public.%I for insert to authenticated with check(private.is_member(school_id))',t||'_insert',t);
    execute format('create policy %I on public.%I for update to authenticated using(private.is_member(school_id)) with check(private.is_member(school_id))',t||'_update',t);
  end loop;
end $$;
create policy allocations_read on public.payment_allocations for select to authenticated using(exists(select 1 from public.payments p where p.id=payment_id and private.is_member(p.school_id)));
create policy allocations_insert on public.payment_allocations for insert to authenticated with check(exists(select 1 from public.payments p where p.id=payment_id and private.is_member(p.school_id)) and exists(select 1 from public.bills b where b.id=bill_id and private.is_member(b.school_id)));
create policy audit_read on public.audit_logs for select to authenticated using(private.is_principal(school_id) or private.is_super());
create policy subscriptions_read on public.subscriptions for select to authenticated using(private.is_principal(school_id) or private.is_super());
create policy usage_read on public.usage_metrics for select to authenticated using(private.is_principal(school_id) or private.is_super());

grant usage on schema public to anon,authenticated;
grant select,update on public.profiles to authenticated;
grant select,update on public.schools,public.school_members,public.invitations to authenticated;
grant select,insert,update on public.classes,public.students,public.cash_accounts,public.activities,public.transactions,public.bills,public.payments to authenticated;
grant select,insert on public.payment_allocations to authenticated;
grant select on public.audit_logs,public.subscriptions,public.usage_metrics to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('transaction-proofs','transaction-proofs',false,5242880,array['image/jpeg','image/png','image/webp','application/pdf']) on conflict(id) do nothing;
create policy proof_read on storage.objects for select to authenticated using(bucket_id='transaction-proofs' and private.is_member((storage.foldername(name))[1]::uuid));
create policy proof_insert on storage.objects for insert to authenticated with check(bucket_id='transaction-proofs' and private.is_member((storage.foldername(name))[1]::uuid));
create policy proof_update on storage.objects for update to authenticated using(bucket_id='transaction-proofs' and private.is_member((storage.foldername(name))[1]::uuid)) with check(bucket_id='transaction-proofs' and private.is_member((storage.foldername(name))[1]::uuid));
