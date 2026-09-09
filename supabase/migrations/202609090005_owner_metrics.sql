alter table public.profiles add column if not exists last_seen_at timestamptz;
create index if not exists profiles_last_seen_at_idx on public.profiles(last_seen_at desc);

create or replace function public.mark_active() returns void language plpgsql security definer set search_path='' as $$
begin
  if (select auth.uid()) is null then raise exception 'Login diperlukan'; end if;
  update public.profiles set last_seen_at=now() where id=(select auth.uid());
  update public.usage_metrics u set last_active_at=now(),updated_at=now()
    where exists(select 1 from public.school_members m where m.school_id=u.school_id and m.user_id=(select auth.uid()) and m.status='active');
end $$;
revoke all on function public.mark_active() from public,anon;
grant execute on function public.mark_active() to authenticated;

create or replace function public.track_report(target_school uuid) returns void language plpgsql security definer set search_path='' as $$
begin
  if not private.is_member(target_school) then raise exception 'Akses ditolak'; end if;
  update public.usage_metrics set reports_count=reports_count+1,last_active_at=now(),updated_at=now() where school_id=target_school;
end $$;
revoke all on function public.track_report(uuid) from public,anon;
grant execute on function public.track_report(uuid) to authenticated;

create or replace function private.refresh_storage_usage() returns trigger language plpgsql security definer set search_path='' as $$
declare sid_text text := split_part(case when tg_op='DELETE' then old.name else new.name end,'/',1); sid uuid; bucket text := case when tg_op='DELETE' then old.bucket_id else new.bucket_id end;
begin
  if bucket <> 'transaction-proofs' or sid_text !~ '^[0-9a-f-]{36}$' then if tg_op='DELETE' then return old; else return new; end if; end if;
  sid := sid_text::uuid;
  update public.usage_metrics set storage_bytes=coalesce((select sum(coalesce((metadata->>'size')::bigint,0)) from storage.objects where bucket_id='transaction-proofs' and name like sid_text||'/%'),0),updated_at=now() where school_id=sid;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;
revoke all on function private.refresh_storage_usage() from public,anon,authenticated;
drop trigger if exists refresh_transaction_proof_usage on storage.objects;
create trigger refresh_transaction_proof_usage after insert or update or delete on storage.objects for each row execute function private.refresh_storage_usage();
