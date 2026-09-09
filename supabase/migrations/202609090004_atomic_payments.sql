create or replace function public.record_payment(target_bill uuid, target_cash uuid, paid numeric, payment_method text)
returns text language plpgsql security definer set search_path='' as $$
declare b public.bills; receipt text; new_paid numeric;
begin
  select * into b from public.bills where id=target_bill for update;
  if b.id is null or not private.is_member(b.school_id) then raise exception 'Tagihan tidak ditemukan atau akses ditolak'; end if;
  if paid <= 0 or paid > b.amount-b.paid_amount then raise exception 'Nominal pembayaran tidak valid'; end if;
  if not exists(select 1 from public.cash_accounts where id=target_cash and school_id=b.school_id and active) then raise exception 'Kas tidak valid'; end if;
  receipt := 'KWT-' || to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS');
  insert into public.payments(school_id,receipt_number,student_id,cash_account_id,amount,method,created_by)
    values(b.school_id,receipt,b.student_id,target_cash,paid,coalesce(nullif(payment_method,''),'Tunai'),(select auth.uid()));
  insert into public.payment_allocations(payment_id,bill_id,amount)
    select id,b.id,paid from public.payments where school_id=b.school_id and receipt_number=receipt;
  new_paid := b.paid_amount+paid;
  update public.bills set paid_amount=new_paid,status=case when new_paid=b.amount then 'paid'::public.bill_status else 'partial'::public.bill_status end where id=b.id;
  insert into public.transactions(school_id,number,kind,cash_account_id,student_id,category,description,amount,created_by)
    values(b.school_id,receipt,'income',target_cash,b.student_id,'Pembayaran siswa',b.title,paid,(select auth.uid()));
  return receipt;
end $$;
revoke all on function public.record_payment(uuid,uuid,numeric,text) from public,anon;
grant execute on function public.record_payment(uuid,uuid,numeric,text) to authenticated;
