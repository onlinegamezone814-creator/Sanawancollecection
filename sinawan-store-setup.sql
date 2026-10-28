-- Run this ONCE in Supabase > SQL Editor > New query > Run.
-- Sets up the tables for the Sinawan Collection store and locks them: everyone can READ, only the admin can CHANGE.
-- Works in a new Supabase project, or in one you already use (all store tables start with "store_").

-- 1) who is the admin (the same email you create under Authentication > Users)
create table if not exists admins (email text primary key);
insert into admins (email) values (lower('Onlinegamezone814@gmail.com')) on conflict do nothing;   -- change to your own email if needed

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as
$$ select exists (select 1 from admins where email = lower(coalesce(auth.jwt() ->> 'email', ''))) $$;

alter table admins enable row level security;

-- 2) tables
create table if not exists store_settings   (key text primary key, value text not null default '');
create table if not exists store_categories (
  id bigint generated always as identity primary key,
  name text not null, sort int not null default 0, active boolean not null default true
);
create table if not exists store_products (
  id bigint generated always as identity primary key,
  name text not null,
  category text not null default '',
  price numeric not null default 0,
  old_price numeric,
  sizes text not null default '',
  description text not null default '',
  images jsonb not null default '[]'::jsonb,
  in_stock boolean not null default true,
  active boolean not null default true,
  sort int not null default 0,
  created_at timestamptz not null default now()
);
create table if not exists store_slides (
  id bigint generated always as identity primary key,
  image_url text not null, title text not null default '', subtitle text not null default '',
  sort int not null default 0, active boolean not null default true
);

-- 3) permissions
alter table store_settings   enable row level security;
alter table store_categories enable row level security;
alter table store_products   enable row level security;
alter table store_slides     enable row level security;

drop policy if exists "public read" on store_settings;   drop policy if exists "admin write" on store_settings;
drop policy if exists "public read" on store_categories; drop policy if exists "admin write" on store_categories;
drop policy if exists "public read" on store_products;   drop policy if exists "admin write" on store_products;
drop policy if exists "public read" on store_slides;     drop policy if exists "admin write" on store_slides;

create policy "public read" on store_settings   for select using (true);
create policy "admin write" on store_settings   for all to authenticated using (is_admin()) with check (is_admin());
create policy "public read" on store_categories for select using (true);
create policy "admin write" on store_categories for all to authenticated using (is_admin()) with check (is_admin());
create policy "public read" on store_products   for select using (true);
create policy "admin write" on store_products   for all to authenticated using (is_admin()) with check (is_admin());
create policy "public read" on store_slides     for select using (true);
create policy "admin write" on store_slides     for all to authenticated using (is_admin()) with check (is_admin());

-- 4) a public folder for the pictures (without it pictures still work, but are stored inside the database)
insert into storage.buckets (id, name, public) values ('store', 'store', true) on conflict (id) do nothing;
drop policy if exists "store read"   on storage.objects;
drop policy if exists "store add"    on storage.objects;
drop policy if exists "store change" on storage.objects;
drop policy if exists "store delete" on storage.objects;
create policy "store read"   on storage.objects for select using (bucket_id = 'store');
create policy "store add"    on storage.objects for insert to authenticated with check (bucket_id = 'store' and is_admin());
create policy "store change" on storage.objects for update to authenticated using (bucket_id = 'store' and is_admin()) with check (bucket_id = 'store' and is_admin());
create policy "store delete" on storage.objects for delete to authenticated using (bucket_id = 'store' and is_admin());

-- 5) starting data
insert into store_settings (key, value) values
  ('whatsapp', '923012193254'), ('facebook', ''), ('instagram', ''), ('delivery_charge', '250'), ('free_over', '5000')
on conflict (key) do nothing;

insert into store_categories (name, sort)
select n, i * 10 from unnest(array['Clothes', 'Shoes', 'Bed Sheets', 'Kids Clothes']) with ordinality as t(n, i)
where not exists (select 1 from store_categories);
