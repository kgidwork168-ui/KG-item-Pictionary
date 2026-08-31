-- KG MATERIAL CATALOGUE PRO - SUPABASE SETUP
-- Run once in Supabase -> SQL Editor for a NEW project.
create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table if not exists public.categories(
  id uuid primary key default gen_random_uuid(),
  name_en text not null,
  name_zh text not null,
  sort_order integer not null default 100,
  created_at timestamptz not null default now()
);

create table if not exists public.products(
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete restrict,
  name_en text not null,
  name_zh text not null,
  image_path text,
  image_url text,
  sort_order integer not null default 100,
  created_at timestamptz not null default now()
);

-- One product can have unlimited price combinations.
-- size_text is optional.
-- color_text is optional.
-- both may be blank.
create table if not exists public.product_variants(
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  size_text text,
  color_text text,
  price numeric(12,2) not null check(price >= 0),
  price_unit text,
  sort_order integer not null default 100,
  created_at timestamptz not null default now()
);

create index if not exists products_category_idx on public.products(category_id);
create index if not exists product_variants_product_idx on public.product_variants(product_id);

create table if not exists public.admin_users(
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.admin_users a where a.user_id=(select auth.uid())); $$;
revoke all on function private.is_admin() from public,anon;
grant execute on function private.is_admin() to authenticated;

alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.admin_users enable row level security;

revoke all on table public.categories from anon,authenticated;
revoke all on table public.products from anon,authenticated;
revoke all on table public.product_variants from anon,authenticated;
revoke all on table public.admin_users from anon,authenticated;
grant select on table public.categories to anon,authenticated;
grant select on table public.products to anon,authenticated;
grant select on table public.product_variants to anon,authenticated;
grant insert,update,delete on table public.categories to authenticated;
grant insert,update,delete on table public.products to authenticated;
grant insert,update,delete on table public.product_variants to authenticated;
grant select on table public.admin_users to authenticated;

drop policy if exists "public read categories" on public.categories;
drop policy if exists "admin write categories" on public.categories;
drop policy if exists "public read products" on public.products;
drop policy if exists "admin write products" on public.products;
drop policy if exists "public read variants" on public.product_variants;
drop policy if exists "admin write variants" on public.product_variants;
drop policy if exists "read own admin row" on public.admin_users;
create policy "public read categories" on public.categories for select to anon,authenticated using(true);
create policy "admin write categories" on public.categories for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "public read products" on public.products for select to anon,authenticated using(true);
create policy "admin write products" on public.products for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "public read variants" on public.product_variants for select to anon,authenticated using(true);
create policy "admin write variants" on public.product_variants for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy "read own admin row" on public.admin_users for select to authenticated using((select auth.uid())=user_id);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "admin upload product images" on storage.objects;
drop policy if exists "admin update product images" on storage.objects;
drop policy if exists "admin delete product images" on storage.objects;
create policy "admin upload product images" on storage.objects for insert to authenticated with check(bucket_id='product-images' and (select private.is_admin()));
create policy "admin update product images" on storage.objects for update to authenticated using(bucket_id='product-images' and (select private.is_admin())) with check(bucket_id='product-images' and (select private.is_admin()));
create policy "admin delete product images" on storage.objects for delete to authenticated using(bucket_id='product-images' and (select private.is_admin()));

insert into public.categories(name_en,name_zh,sort_order)
select * from (values
 ('Board','板材',10),('Wall Plug','墙塞',20),('Wood Board','木板',30),('Metal','金属',40),('Screw','螺丝',50)
) v(name_en,name_zh,sort_order)
where not exists(select 1 from public.categories);

-- CREATE ADMIN:
-- Supabase -> Authentication -> Users -> Add User
-- Copy the UUID, then run:
-- insert into public.admin_users(user_id) values('PASTE-ADMIN-USER-UUID-HERE') on conflict do nothing;
