-- KG Material Pictionary: shared setup / safe upgrade
-- This website stores NO price in its interface and never selects price fields.

create extension if not exists pgcrypto;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name_en text not null,
  name_zh text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id) on delete restrict,
  name_en text not null,
  name_zh text,
  image_url text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  manual_number text,
  size text,
  colour_en text,
  colour_zh text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Safe upgrades for databases created by an earlier version.
alter table public.categories add column if not exists name_en text;
alter table public.categories add column if not exists name_zh text;
alter table public.categories add column if not exists sort_order integer not null default 0;
alter table public.categories add column if not exists is_active boolean not null default true;

alter table public.products add column if not exists category_id uuid references public.categories(id) on delete restrict;
alter table public.products add column if not exists name_en text;
alter table public.products add column if not exists name_zh text;
alter table public.products add column if not exists image_url text;
alter table public.products add column if not exists sort_order integer not null default 0;
alter table public.products add column if not exists is_active boolean not null default true;

alter table public.product_variants add column if not exists product_id uuid references public.products(id) on delete cascade;
alter table public.product_variants add column if not exists manual_number text;
alter table public.product_variants add column if not exists size text;
alter table public.product_variants add column if not exists colour_en text;
alter table public.product_variants add column if not exists colour_zh text;
alter table public.product_variants add column if not exists sort_order integer not null default 0;
alter table public.product_variants add column if not exists is_active boolean not null default true;

-- Copy common American-spelling columns into the website's colour columns when present.
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='product_variants' and column_name='color_en') then
    execute 'update public.product_variants set colour_en = coalesce(colour_en, color_en)';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='product_variants' and column_name='color_zh') then
    execute 'update public.product_variants set colour_zh = coalesce(colour_zh, color_zh)';
  end if;
end $$;

drop index if exists public.product_variants_manual_unique_idx;
create unique index product_variants_manual_unique_idx
  on public.product_variants (lower(trim(manual_number)))
  where manual_number is not null and trim(manual_number) <> '';

create index if not exists products_category_idx on public.products(category_id);
create index if not exists variants_product_idx on public.product_variants(product_id);

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$ select exists(select 1 from public.admins where user_id = auth.uid()) $$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.admins enable row level security;

drop policy if exists "Public reads categories" on public.categories;
drop policy if exists "Public reads products" on public.products;
drop policy if exists "Public reads variants" on public.product_variants;
drop policy if exists "Admins manage categories" on public.categories;
drop policy if exists "Admins manage products" on public.products;
drop policy if exists "Admins manage variants" on public.product_variants;
drop policy if exists "Admin reads own role" on public.admins;

create policy "Public reads categories" on public.categories for select using (is_active = true or public.is_admin());
create policy "Public reads products" on public.products for select using (is_active = true or public.is_admin());
create policy "Public reads variants" on public.product_variants for select using (is_active = true or public.is_admin());
create policy "Admins manage categories" on public.categories for all using (public.is_admin()) with check (public.is_admin());
create policy "Admins manage products" on public.products for all using (public.is_admin()) with check (public.is_admin());
create policy "Admins manage variants" on public.product_variants for all using (public.is_admin()) with check (public.is_admin());
create policy "Admin reads own role" on public.admins for select using (user_id = auth.uid());

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

drop policy if exists "Public reads product images" on storage.objects;
drop policy if exists "Admins upload product images" on storage.objects;
drop policy if exists "Admins update product images" on storage.objects;
drop policy if exists "Admins delete product images" on storage.objects;

create policy "Public reads product images" on storage.objects for select using (bucket_id = 'product-images');
create policy "Admins upload product images" on storage.objects for insert to authenticated with check (bucket_id = 'product-images' and public.is_admin());
create policy "Admins update product images" on storage.objects for update to authenticated using (bucket_id = 'product-images' and public.is_admin()) with check (bucket_id = 'product-images' and public.is_admin());
create policy "Admins delete product images" on storage.objects for delete to authenticated using (bucket_id = 'product-images' and public.is_admin());

-- AFTER creating the admin user in Supabase Authentication, run this separately:
-- insert into public.admins (user_id) values ('PASTE-AUTH-USER-UUID-HERE');

-- Optional starter categories. Remove this block if your categories already exist.
insert into public.categories (name_en, name_zh, sort_order)
select v.name_en, v.name_zh, v.sort_order
from (values
  ('Board', '板材', 10),
  ('Wall Plug', '墙塞', 20),
  ('Wood Board', '木板', 30),
  ('Metal', '金属', 40),
  ('Screw', '螺丝', 50)
) as v(name_en, name_zh, sort_order)
where not exists (select 1 from public.categories c where lower(c.name_en) = lower(v.name_en));
