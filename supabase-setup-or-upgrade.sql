-- ============================================================
-- KG MATERIAL PICTIONARY - SHARED SUPABASE SETUP / UPGRADE
-- Use ONE Supabase project for BOTH GitHub Pages repositories.
-- Safe for a new project and designed to upgrade older versions.
-- ============================================================

create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

-- Categories
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name_en text not null,
  name_zh text not null,
  sort_order integer not null default 100,
  created_at timestamptz not null default now()
);

-- Products
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id) on delete restrict,
  name_en text not null,
  name_zh text not null,
  image_path text,
  image_url text,
  sort_order integer not null default 100,
  created_at timestamptz not null default now()
);

-- Variants
create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  manual_number text,
  size_text text,
  color_text text,
  price numeric(12,2),
  price_unit text,
  sort_order integer not null default 100,
  created_at timestamptz not null default now()
);

-- Upgrade older product_variants tables safely
alter table public.product_variants add column if not exists manual_number text;
alter table public.product_variants add column if not exists size_text text;
alter table public.product_variants add column if not exists color_text text;
alter table public.product_variants add column if not exists price numeric(12,2);
alter table public.product_variants add column if not exists price_unit text;
alter table public.product_variants add column if not exists sort_order integer default 100;

create index if not exists products_category_idx on public.products(category_id);
create index if not exists product_variants_product_idx on public.product_variants(product_id);

-- Manual No. must be unique WHEN it has a value.
-- Existing blank rows are allowed so old data does not break this migration.
drop index if exists public.product_variants_manual_idx;

-- IMPORTANT:
-- If this next statement fails with duplicate values, run the duplicate-check query
-- at the bottom of this file, fix duplicates, then run this CREATE INDEX again.
create unique index if not exists product_variants_manual_unique_idx
on public.product_variants (lower(trim(manual_number)))
where manual_number is not null and trim(manual_number) <> '';

-- Admin list
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists(
    select 1
    from public.admin_users
    where user_id=(select auth.uid())
  );
$$;

revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;

-- RLS
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.admin_users enable row level security;

revoke all on table public.categories from anon, authenticated;
revoke all on table public.products from anon, authenticated;
revoke all on table public.product_variants from anon, authenticated;
revoke all on table public.admin_users from anon, authenticated;

grant select on table public.categories to anon, authenticated;
grant select on table public.products to anon, authenticated;
grant select on table public.product_variants to anon, authenticated;

grant insert, update, delete on table public.categories to authenticated;
grant insert, update, delete on table public.products to authenticated;
grant insert, update, delete on table public.product_variants to authenticated;
grant select on table public.admin_users to authenticated;

drop policy if exists "public read categories" on public.categories;
drop policy if exists "admin write categories" on public.categories;
drop policy if exists "public read products" on public.products;
drop policy if exists "admin write products" on public.products;
drop policy if exists "public read variants" on public.product_variants;
drop policy if exists "admin write variants" on public.product_variants;
drop policy if exists "read own admin row" on public.admin_users;

create policy "public read categories"
on public.categories for select
to anon, authenticated
using(true);

create policy "admin write categories"
on public.categories for all
to authenticated
using((select private.is_admin()))
with check((select private.is_admin()));

create policy "public read products"
on public.products for select
to anon, authenticated
using(true);

create policy "admin write products"
on public.products for all
to authenticated
using((select private.is_admin()))
with check((select private.is_admin()));

create policy "public read variants"
on public.product_variants for select
to anon, authenticated
using(true);

create policy "admin write variants"
on public.product_variants for all
to authenticated
using((select private.is_admin()))
with check((select private.is_admin()));

create policy "read own admin row"
on public.admin_users for select
to authenticated
using((select auth.uid())=user_id);

-- Storage
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'product-images',
  'product-images',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp']
)
on conflict(id) do update set
  public=excluded.public,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "admin upload product images" on storage.objects;
drop policy if exists "admin update product images" on storage.objects;
drop policy if exists "admin delete product images" on storage.objects;

create policy "admin upload product images"
on storage.objects for insert
to authenticated
with check(bucket_id='product-images' and (select private.is_admin()));

create policy "admin update product images"
on storage.objects for update
to authenticated
using(bucket_id='product-images' and (select private.is_admin()))
with check(bucket_id='product-images' and (select private.is_admin()));

create policy "admin delete product images"
on storage.objects for delete
to authenticated
using(bucket_id='product-images' and (select private.is_admin()));

-- Starter categories only when categories table is empty
insert into public.categories(name_en,name_zh,sort_order)
select * from (values
  ('Board','板材',10),
  ('Wall Plug','墙塞',20),
  ('Wood Board','木板',30),
  ('Metal','金属',40),
  ('Screw','螺丝',50)
) v(name_en,name_zh,sort_order)
where not exists(select 1 from public.categories);

-- ============================================================
-- CREATE ADMIN ACCOUNT
-- Supabase -> Authentication -> Users -> Add User
-- Copy its UUID, then run:
--
-- insert into public.admin_users(user_id)
-- values('PASTE-ADMIN-USER-UUID-HERE')
-- on conflict do nothing;
-- ============================================================

-- ============================================================
-- DUPLICATE MANUAL NO. CHECK
-- Run this ONLY if the unique-index statement reports duplicates.
--
-- select lower(trim(manual_number)) as manual_no, count(*) as qty
-- from public.product_variants
-- where manual_number is not null and trim(manual_number) <> ''
-- group by lower(trim(manual_number))
-- having count(*) > 1;
-- ============================================================
