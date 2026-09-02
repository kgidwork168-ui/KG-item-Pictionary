-- ONE-TIME MAIN ADMIN SETUP
-- Login data is stored in public.admin_accounts in Supabase.
-- The password is saved only as a bcrypt hash, never as readable text.
--
-- Before you run this privately in Supabase SQL Editor:
-- Replace CHANGE_TO_YOUR_MAIN_ADMIN_PASSWORD with the password you want.
-- Do not put the completed SQL file into a public GitHub repository.

insert into public.admin_accounts
  (username, display_name, password_hash, is_main_admin, is_active, updated_at)
values
  ('chester', 'Chester', extensions.crypt('CHANGE_TO_YOUR_MAIN_ADMIN_PASSWORD', extensions.gen_salt('bf', 12)), true, true, now())
on conflict ((lower(trim(username))))
do update set
  display_name = excluded.display_name,
  password_hash = excluded.password_hash,
  is_main_admin = true,
  is_active = true,
  updated_at = now();

select username, display_name, is_main_admin, is_active
from public.admin_accounts
where lower(username) = 'chester';
