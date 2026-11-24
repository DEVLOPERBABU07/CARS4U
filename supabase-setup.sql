-- CARS4U tracking + customer details. Run in Supabase: SQL Editor -> New query -> paste -> Run.
-- Safe to run again. BEFORE running, change CHANGE_THIS_PASSWORD (near the end) to your own long password.

create table if not exists public.car_views (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  visitor_id  text not null check (char_length(visitor_id) <= 64),
  session_id  text check (char_length(session_id) <= 64),
  car_id      text not null check (char_length(car_id) <= 60),
  car_title   text check (char_length(car_title) <= 200),
  seconds     int  not null check (seconds between 1 and 3600),
  device      text check (char_length(device) <= 20),
  referrer    text check (char_length(referrer) <= 300)
);
alter table public.car_views enable row level security;
revoke all on public.car_views from anon, authenticated;
grant insert on public.car_views to anon;
drop policy if exists "visitors can insert" on public.car_views;
create policy "visitors can insert" on public.car_views for insert to anon with check (true);

create table if not exists public.visitors (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  visitor_id  text not null check (char_length(visitor_id) <= 64),
  name        text check (char_length(name) <= 100),
  phone       text not null check (phone ~ '^[0-9]{10}$'),
  email       text check (char_length(email) <= 150 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);
alter table public.visitors enable row level security;
revoke all on public.visitors from anon, authenticated;
grant insert on public.visitors to anon;
drop policy if exists "visitors can insert" on public.visitors;
create policy "visitors can insert" on public.visitors for insert to anon with check (true);

drop function if exists public.car_report(text);
create function public.car_report(p text)
returns table (visitor_id text, name text, phone text, email text, car_title text, views bigint, total_seconds bigint, last_seen timestamptz, device text)
language sql security definer set search_path = public as $$
  select v.visitor_id, c.name, c.phone, c.email, v.car_title, count(*), sum(v.seconds)::bigint, max(v.created_at), max(v.device)
  from public.car_views v
  left join lateral (select x.name, x.phone, x.email from public.visitors x where x.visitor_id = v.visitor_id order by x.id desc limit 1) c on true
  where p = 'CHANGE_THIS_PASSWORD'
  group by v.visitor_id, c.name, c.phone, c.email, v.car_title
  order by max(v.created_at) desc
  limit 500;
$$;
revoke all on function public.car_report(text) from public;
grant execute on function public.car_report(text) to anon;
