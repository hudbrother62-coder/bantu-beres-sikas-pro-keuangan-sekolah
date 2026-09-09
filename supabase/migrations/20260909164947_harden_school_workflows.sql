alter table public.schools
  add column if not exists phone text,
  add column if not exists email text,
  add column if not exists province text,
  add column if not exists postal_code text,
  add column if not exists school_level text;

alter table public.transactions add column if not exists activity_name text;
alter table public.payments add column if not exists proof_path text;

insert into public.cash_accounts(school_id,name,type)
select s.id,v.name,v.type
from public.schools s
cross join (values ('Kas Tunai','cash'),('E-Wallet','ewallet'),('Rekening','bank')) v(name,type)
on conflict(school_id,name) do update set active=true,type=excluded.type;

create or replace function public.create_school(school_name text, school_npsn text, school_address text, school_city text, year_label text)
returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
  if (select auth.uid()) is null then raise exception 'Login diperlukan'; end if;
  select school_id into sid from public.school_members
  where user_id=(select auth.uid()) and status='active'
  order by created_at limit 1;
  if sid is not null then return sid; end if;
  if coalesce(trim(school_name),'')='' then raise exception 'Nama sekolah wajib diisi'; end if;
  insert into public.schools(name,npsn,address,city,academic_year,created_by)
  values(trim(school_name),nullif(trim(school_npsn),''),nullif(trim(school_address),''),nullif(trim(school_city),''),coalesce(nullif(trim(year_label),''),'2026/2027'),(select auth.uid())) returning id into sid;
  insert into public.school_members(school_id,user_id,role) values(sid,(select auth.uid()),'principal');
  insert into public.cash_accounts(school_id,name,type) values(sid,'Kas Tunai','cash'),(sid,'E-Wallet','ewallet'),(sid,'Rekening','bank');
  insert into public.subscriptions(school_id) values(sid);
  insert into public.usage_metrics(school_id) values(sid);
  return sid;
end $$;

create or replace function public.create_invitation(target_school uuid)
returns text language plpgsql security definer set search_path='' as $$
declare raw_token text := pg_catalog.encode(extensions.gen_random_bytes(24),'hex');
begin
  if not private.is_principal(target_school) then raise exception 'Hanya Kepala Sekolah yang dapat membuat undangan'; end if;
  insert into public.invitations(school_id,token_hash,expires_at,invited_by)
  values(target_school,pg_catalog.encode(extensions.digest(raw_token,'sha256'),'hex'),pg_catalog.now()+interval '7 days',(select auth.uid()));
  return raw_token;
end $$;

create or replace function public.accept_invitation(raw_token text)
returns uuid language plpgsql security definer set search_path='' as $$
declare inv public.invitations; hashed text := pg_catalog.encode(extensions.digest(raw_token,'sha256'),'hex'); existing_school uuid;
begin
  if (select auth.uid()) is null then raise exception 'Login diperlukan'; end if;
  select school_id into existing_school from public.school_members where user_id=(select auth.uid()) and status='active' order by created_at limit 1;
  select * into inv from public.invitations where token_hash=hashed and accepted_at is null and revoked_at is null and expires_at>pg_catalog.now() for update;
  if inv.id is null then raise exception 'Undangan tidak valid, sudah digunakan, atau sudah berakhir'; end if;
  if existing_school is not null and existing_school<>inv.school_id then raise exception 'Akun ini sudah terhubung ke sekolah lain'; end if;
  insert into public.school_members(school_id,user_id,role) values(inv.school_id,(select auth.uid()),'staff')
  on conflict(school_id,user_id) do update set status='active';
  update public.invitations set accepted_by=(select auth.uid()),accepted_at=pg_catalog.now() where id=inv.id;
  return inv.school_id;
end $$;

drop function if exists public.record_payment(uuid,uuid,numeric,text);
create or replace function public.record_payment(target_bill uuid,target_cash uuid,paid numeric,payment_method text,payment_proof text default null)
returns text language plpgsql security definer set search_path='' as $$
declare b public.bills; receipt text; new_paid numeric; new_payment_id uuid;
begin
  select * into b from public.bills where id=target_bill for update;
  if b.id is null or not private.is_member(b.school_id) then raise exception 'Tagihan tidak ditemukan atau akses ditolak'; end if;
  if paid<=0 or paid>b.amount-b.paid_amount then raise exception 'Nominal pembayaran harus lebih dari Rp0 dan tidak boleh melebihi sisa tagihan'; end if;
  if not exists(select 1 from public.cash_accounts where id=target_cash and school_id=b.school_id and active) then raise exception 'Kas, E-Wallet, atau rekening tidak valid'; end if;
  receipt := 'KWT-'||to_char(pg_catalog.clock_timestamp(),'YYYYMMDDHH24MISSMS');
  insert into public.payments(school_id,receipt_number,student_id,cash_account_id,amount,method,proof_path,created_by)
  values(b.school_id,receipt,b.student_id,target_cash,paid,coalesce(nullif(payment_method,''),'Tunai'),payment_proof,(select auth.uid())) returning id into new_payment_id;
  insert into public.payment_allocations(payment_id,bill_id,amount) values(new_payment_id,b.id,paid);
  new_paid:=b.paid_amount+paid;
  update public.bills set paid_amount=new_paid,status=case when new_paid=b.amount then 'paid'::public.bill_status else 'partial'::public.bill_status end where id=b.id;
  insert into public.transactions(school_id,number,kind,cash_account_id,student_id,category,description,amount,proof_path,created_by)
  values(b.school_id,receipt,'income',target_cash,b.student_id,'Pembayaran siswa',b.title,paid,payment_proof,(select auth.uid()));
  return receipt;
end $$;

create or replace function private.assign_activity_code() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if coalesce(trim(new.code),'')='' then
    new.code:='KGT-'||to_char(current_date,'YYYYMM')||'-'||upper(substr(pg_catalog.encode(extensions.gen_random_bytes(4),'hex'),1,6));
  end if;
  return new;
end $$;
drop trigger if exists assign_activity_code on public.activities;
create trigger assign_activity_code before insert on public.activities for each row execute function private.assign_activity_code();

revoke all on function public.create_school(text,text,text,text,text),public.create_invitation(uuid),public.accept_invitation(text),public.record_payment(uuid,uuid,numeric,text,text) from public,anon;
grant execute on function public.create_school(text,text,text,text,text),public.create_invitation(uuid),public.accept_invitation(text),public.record_payment(uuid,uuid,numeric,text,text) to authenticated;
revoke all on function private.assign_activity_code() from public,anon,authenticated;
