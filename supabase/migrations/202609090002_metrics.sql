create or replace function private.refresh_usage() returns trigger language plpgsql security definer set search_path='' as $$
declare sid uuid := coalesce(new.school_id,old.school_id);
begin
  insert into public.usage_metrics(school_id,students_count,transactions_count,last_active_at,updated_at)
  values(sid,(select count(*) from public.students where school_id=sid and status='active'),(select count(*) from public.transactions where school_id=sid),now(),now())
  on conflict(school_id) do update set students_count=excluded.students_count,transactions_count=excluded.transactions_count,last_active_at=now(),updated_at=now();
  return coalesce(new,old);
end $$;
revoke all on function private.refresh_usage() from public;
create trigger refresh_usage_students after insert or update or delete on public.students for each row execute function private.refresh_usage();
create trigger refresh_usage_transactions after insert or update or delete on public.transactions for each row execute function private.refresh_usage();

create or replace function private.audit_change() returns trigger language plpgsql security definer set search_path='' as $$
declare sid uuid := coalesce(new.school_id,old.school_id); eid text := coalesce(new.id,old.id)::text;
begin
  insert into public.audit_logs(school_id,user_id,action,entity,entity_id,metadata)
  values(sid,(select auth.uid()),lower(tg_op),tg_table_name,eid,jsonb_build_object('status',coalesce(to_jsonb(new)->>'status',to_jsonb(old)->>'status')));
  return coalesce(new,old);
end $$;
revoke all on function private.audit_change() from public;
create trigger audit_transactions after insert or update on public.transactions for each row execute function private.audit_change();
create trigger audit_bills after insert or update on public.bills for each row execute function private.audit_change();
create trigger audit_payments after insert on public.payments for each row execute function private.audit_change();
