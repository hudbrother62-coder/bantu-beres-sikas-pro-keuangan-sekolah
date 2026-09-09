create table if not exists public.registration_rate_limits(
  fingerprint text primary key,
  attempts integer not null default 1,
  window_started_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.registration_rate_limits enable row level security;
revoke all on public.registration_rate_limits from public,anon,authenticated;
grant select,insert,update,delete on public.registration_rate_limits to service_role;

create or replace function public.consume_registration_attempt(client_fingerprint text)
returns boolean language plpgsql security invoker set search_path='' as $$
declare current_attempts integer;
begin
  if current_user <> 'service_role' then raise exception 'Akses ditolak'; end if;
  insert into public.registration_rate_limits(fingerprint,attempts,window_started_at,updated_at)
  values(client_fingerprint,1,now(),now())
  on conflict(fingerprint) do update set
    attempts=case when public.registration_rate_limits.window_started_at < now()-interval '30 minutes' then 1 else public.registration_rate_limits.attempts+1 end,
    window_started_at=case when public.registration_rate_limits.window_started_at < now()-interval '30 minutes' then now() else public.registration_rate_limits.window_started_at end,
    updated_at=now()
  returning attempts into current_attempts;
  return current_attempts<=5;
end $$;
revoke all on function public.consume_registration_attempt(text) from public,anon,authenticated;
grant execute on function public.consume_registration_attempt(text) to service_role;
