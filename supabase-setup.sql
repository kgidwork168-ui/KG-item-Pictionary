-- KG Material Pictionary: database, username login and security setup
-- Login accounts are stored in Supabase. No email address is required.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

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

-- Safe upgrades for material tables created by an earlier version.
alter table public.categories add column if not exists name_en text;
alter table public.categories add column if not exists name_zh text;
alter table public.categories add column if not exists sort_order integer not null default 0;
alter table public.categories add column if not exists is_active boolean not null default true;
alter table public.categories add column if not exists updated_at timestamptz not null default now();

alter table public.products add column if not exists category_id uuid references public.categories(id) on delete restrict;
alter table public.products add column if not exists name_en text;
alter table public.products add column if not exists name_zh text;
alter table public.products add column if not exists image_url text;
alter table public.products add column if not exists sort_order integer not null default 0;
alter table public.products add column if not exists is_active boolean not null default true;
alter table public.products add column if not exists updated_at timestamptz not null default now();

alter table public.product_variants add column if not exists product_id uuid references public.products(id) on delete cascade;
alter table public.product_variants add column if not exists manual_number text;
alter table public.product_variants add column if not exists size text;
alter table public.product_variants add column if not exists colour_en text;
alter table public.product_variants add column if not exists colour_zh text;
alter table public.product_variants add column if not exists sort_order integer not null default 0;
alter table public.product_variants add column if not exists is_active boolean not null default true;

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

-- Username/password admin accounts. Passwords are stored only as bcrypt hashes.
create table if not exists public.admin_accounts (
  id uuid primary key default gen_random_uuid(),
  username text not null,
  display_name text not null,
  password_hash text not null,
  is_main_admin boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists admin_accounts_username_unique_idx
  on public.admin_accounts (lower(trim(username)));

create table if not exists public.admin_sessions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.admin_accounts(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  last_used_at timestamptz not null default now()
);

create index if not exists admin_sessions_account_idx on public.admin_sessions(account_id);
create index if not exists admin_sessions_expiry_idx on public.admin_sessions(expires_at);

create table if not exists public.admin_login_attempts (
  attempt_key text primary key,
  attempt_count integer not null default 0,
  window_started_at timestamptz not null default now(),
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);

create or replace function public.verify_pictionary_admin(p_username text, p_password text)
returns table (id uuid, username text, display_name text, is_main_admin boolean, is_active boolean)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select a.id, a.username, a.display_name, a.is_main_admin, a.is_active
  from public.admin_accounts a
  where lower(trim(a.username)) = lower(trim(p_username))
    and a.is_active = true
    and a.password_hash = crypt(p_password, a.password_hash)
  limit 1
$$;

create or replace function public.hash_pictionary_password(p_password text)
returns text
language sql
volatile
security definer
set search_path = public, extensions
as $$ select crypt(p_password, gen_salt('bf', 12)) $$;

revoke all on function public.verify_pictionary_admin(text, text) from public, anon, authenticated;
revoke all on function public.hash_pictionary_password(text) from public, anon, authenticated;
grant execute on function public.verify_pictionary_admin(text, text) to service_role;
grant execute on function public.hash_pictionary_password(text) to service_role;

-- Public visitors can only read active Pictionary data.
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.admin_accounts enable row level security;
alter table public.admin_sessions enable row level security;
alter table public.admin_login_attempts enable row level security;

drop policy if exists "Public reads categories" on public.categories;
drop policy if exists "Public reads products" on public.products;
drop policy if exists "Public reads variants" on public.product_variants;
drop policy if exists "Admins manage categories" on public.categories;
drop policy if exists "Admins manage products" on public.products;
drop policy if exists "Admins manage variants" on public.product_variants;

create policy "Public reads categories" on public.categories for select using (is_active = true);
create policy "Public reads products" on public.products for select using (is_active = true);
create policy "Public reads variants" on public.product_variants for select using (is_active = true);

-- Login/account/session tables deliberately have no public RLS policies.
-- The protected Edge Function is the only writer for all admin operations.

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

drop policy if exists "Public reads product images" on storage.objects;
drop policy if exists "Admins upload product images" on storage.objects;
drop policy if exists "Admins update product images" on storage.objects;
drop policy if exists "Admins delete product images" on storage.objects;
create policy "Public reads product images" on storage.objects for select using (bucket_id = 'product-images');

delete from public.admin_sessions where expires_at <= now();

-- Optional starter categories.
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
