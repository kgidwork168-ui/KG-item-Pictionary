-- ============================================================
-- KG MATERIAL CATALOGUE - SUPABASE SETUP
-- Run this ONCE in Supabase Dashboard -> SQL Editor.
-- ============================================================

-- 1) Extensions
create extension if not exists pgcrypto;

-- 2) Private schema for secure helper functions
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

-- 3) Categories
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name_en text not null,
  name_zh text not null,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4) Products
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete restrict,
  name_en text not null,
  name_zh text not null,
  size_text text,
  colors_text text,
  price numeric(12,2) check (price is null or price >= 0),
  price_unit text,
  image_path text,
  image_url text,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists products_category_id_idx on public.products(category_id);
create index if not exists products_sort_order_idx on public.products(sort_order);
create index if not exists categories_sort_order_idx on public.categories(sort_order);

-- 5) Approved admin accounts
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- 6) Secure admin checker
create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users a
    where a.user_id = (select auth.uid())
  );
$$;

revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;

-- 7) Turn on Row Level Security
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.admin_users enable row level security;

-- 8) Least-privilege table grants
revoke all on table public.categories from anon, authenticated;
revoke all on table public.products from anon, authenticated;
revoke all on table public.admin_users from anon, authenticated;

grant select on table public.categories to anon, authenticated;
grant select on table public.products to anon, authenticated;

grant insert, update, delete on table public.categories to authenticated;
grant insert, update, delete on table public.products to authenticated;

grant select on table public.admin_users to authenticated;

-- 9) Drop old policies if script is run again
drop policy if exists "Public can read categories" on public.categories;
drop policy if exists "Admins can insert categories" on public.categories;
drop policy if exists "Admins can update categories" on public.categories;
drop policy if exists "Admins can delete categories" on public.categories;

drop policy if exists "Public can read products" on public.products;
drop policy if exists "Admins can insert products" on public.products;
drop policy if exists "Admins can update products" on public.products;
drop policy if exists "Admins can delete products" on public.products;

drop policy if exists "Users can read own admin row" on public.admin_users;

-- 10) Public read policies
create policy "Public can read categories"
on public.categories for select
to anon, authenticated
using (true);

create policy "Public can read products"
on public.products for select
to anon, authenticated
using (true);

-- 11) Admin-only write policies
create policy "Admins can insert categories"
on public.categories for insert
to authenticated
with check ((select private.is_admin()));

create policy "Admins can update categories"
on public.categories for update
to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy "Admins can delete categories"
on public.categories for delete
to authenticated
using ((select private.is_admin()));

create policy "Admins can insert products"
on public.products for insert
to authenticated
with check ((select private.is_admin()));

create policy "Admins can update products"
on public.products for update
to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy "Admins can delete products"
on public.products for delete
to authenticated
using ((select private.is_admin()));

-- Admin page can verify only its own admin row.
create policy "Users can read own admin row"
on public.admin_users for select
to authenticated
using ((select auth.uid()) = user_id);

-- 12) Public Storage bucket for catalogue photos
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- 13) Storage write policies: admin only
drop policy if exists "Admins can upload product images" on storage.objects;
drop policy if exists "Admins can update product images" on storage.objects;
drop policy if exists "Admins can delete product images" on storage.objects;

create policy "Admins can upload product images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and (select private.is_admin())
);

create policy "Admins can update product images"
on storage.objects for update
to authenticated
using (
  bucket_id = 'product-images'
  and (select private.is_admin())
)
with check (
  bucket_id = 'product-images'
  and (select private.is_admin())
);

create policy "Admins can delete product images"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'product-images'
  and (select private.is_admin())
);

-- ============================================================
-- AFTER RUNNING THIS SCRIPT:
--
-- A) Supabase -> Authentication -> Users -> Add user
--    Create your admin email + password.
--
-- B) Copy that user's UUID and run:
--
-- insert into public.admin_users (user_id)
-- values ('PASTE-ADMIN-USER-UUID-HERE')
-- on conflict do nothing;
--
-- C) Optional starter categories:
-- ============================================================

insert into public.categories (name_en, name_zh, sort_order)
select * from (values
  ('Board', '板材', 10),
  ('Wall Plug', '墙塞', 20),
  ('Wood Board', '木板', 30),
  ('Metal', '金属', 40),
  ('Screw', '螺丝', 50)
) as v(name_en, name_zh, sort_order)
where not exists (select 1 from public.categories);
