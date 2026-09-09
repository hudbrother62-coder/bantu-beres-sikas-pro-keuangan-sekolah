create unique index if not exists school_members_one_principal_idx on public.school_members(school_id) where role='principal';

create or replace function private.protect_school_membership() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if old.user_id <> new.user_id or old.school_id <> new.school_id then
    raise exception 'Identitas anggota sekolah tidak dapat dipindahkan';
  end if;
  if old.role <> new.role then
    raise exception 'Role anggota ditentukan oleh sistem dan tidak dapat diubah';
  end if;
  if old.role='principal' and new.status <> 'active' then
    raise exception 'Kepala Sekolah tidak dapat dinonaktifkan';
  end if;
  return new;
end $$;

revoke all on function private.protect_school_membership() from public,anon,authenticated;
drop trigger if exists protect_school_membership on public.school_members;
create trigger protect_school_membership before update on public.school_members for each row execute function private.protect_school_membership();
