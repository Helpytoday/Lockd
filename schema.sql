-- Run this once in Supabase > SQL Editor.

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null check (char_length(username) between 3 and 20),
  created_at timestamptz not null default now()
);

create table sessions (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  verified_seconds int not null,
  break_seconds int not null default 0,
  points int not null,
  created_at timestamptz not null default now()
);
create index on sessions (user_id, ended_at);

alter table profiles enable row level security;
alter table sessions enable row level security;

create policy "profiles readable" on profiles for select using (true);
create policy "insert own profile" on profiles for insert with check (auth.uid() = id);
create policy "read own sessions" on sessions for select using (auth.uid() = user_id);
-- No insert policy on sessions: the only way in is submit_session() below.

create or replace function submit_session(p_started timestamptz, p_ended timestamptz, p_verified int, p_break int)
returns int language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  wall numeric;
  pts int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  wall := extract(epoch from (p_ended - p_started));
  if p_ended > now() + interval '1 minute' then raise exception 'session ends in the future'; end if;
  if wall <= 0 or wall > 8*3600 then raise exception 'bad session length'; end if;
  if p_verified < 0 or p_break < 0 or p_verified + p_break > wall + 5 then raise exception 'impossible totals'; end if;
  if exists (select 1 from sessions where user_id = uid and started_at < p_ended and ended_at > p_started) then
    raise exception 'overlaps another session';
  end if;
  pts := p_verified / 600;   -- integer division: 1 point per full 10 verified minutes
  insert into sessions(user_id, started_at, ended_at, verified_seconds, break_seconds, points)
  values (uid, p_started, p_ended, p_verified, p_break, pts);
  return pts;
end $$;
revoke all on function submit_session from public;
grant execute on function submit_session to authenticated;

create view leaderboard_weekly as
  select p.username, coalesce(sum(s.points),0)::int as points
  from profiles p join sessions s on s.user_id = p.id
  where s.ended_at >= date_trunc('week', now())
  group by p.username;

create view leaderboard_alltime as
  select p.username, coalesce(sum(s.points),0)::int as points
  from profiles p join sessions s on s.user_id = p.id
  group by p.username;

grant select on leaderboard_weekly, leaderboard_alltime to anon, authenticated;
