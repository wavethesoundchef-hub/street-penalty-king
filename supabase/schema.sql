-- =====================================================================
-- Street Penalty King: global faction leaderboard
--
-- Run this once in your Supabase project:
--   Dashboard -> SQL Editor -> New query -> paste this whole file -> Run
-- It is safe to run again (it replaces the functions, keeps your data).
--
-- Security model
--   * Players are Supabase *anonymous* users (Authentication -> Sign In / Providers
--     -> enable "Allow anonymous sign-ins"). No email or password needed.
--   * The game only ever uses the public anon key. Row Level Security is on and
--     there are NO table policies, so nobody can read or write the tables directly.
--   * Everything goes through the spk_* functions below, which validate input,
--     enforce the faction lock, rate-limit submissions and cap counted matches.
-- =====================================================================

create table if not exists public.players (
  id            uuid primary key references auth.users (id) on delete cascade,
  nickname      text not null,
  faction       text not null,
  locked_until  timestamptz not null default now() + interval '30 days',
  switches_left int not null default 1,
  created_at    timestamptz not null default now()
);

create table if not exists public.matches (
  id         bigint generated always as identity primary key,
  player_id  uuid not null references public.players (id) on delete cascade,
  faction    text not null,
  opponent   text not null,
  mode       text not null,
  goals      int not null check (goals between 0 and 5),
  results    text not null check (results ~ '^[gsm]{5}$'),
  counted    boolean not null,
  week       text not null,
  created_at timestamptz not null default now()
);

create index if not exists matches_week_faction on public.matches (week, faction) where counted;
create index if not exists matches_player_time on public.matches (player_id, created_at desc);

alter table public.players enable row level security;
alter table public.matches enable row level security;
revoke all on public.players, public.matches from anon, authenticated;

-- ---------- helpers ----------

create or replace function public.spk_factions() returns text[]
language sql immutable as $$
  select array[
    'cr7','messi','neymar','mbappe','haaland','vini','osimhen','lookman','okocha','kanu',
    'wizkid','davido','outsiders','afrorave','ololade','tems','ayra','kizz','fireboy','ybnl','seyi','shallipopi','odumodu',
    'mainland','island','ikeja','ajegunle','calabar','jos','ibadan','abeokuta','phoilers','abuja'
  ]
$$;

-- Leaderboard week, e.g. 2026-W41 (weeks start Monday, Lagos time)
create or replace function public.spk_week() returns text
language sql stable as $$
  select to_char(now() at time zone 'Africa/Lagos', 'IYYY-"W"IW')
$$;

create or replace function public.spk_clean_nick(p text) returns text
language plpgsql immutable as $$
declare n text := btrim(upper(regexp_replace(coalesce(p, ''), '[^A-Za-z0-9 _.-]', '', 'g')));
begin
  if char_length(n) < 2 or char_length(n) > 12 then
    raise exception 'nickname must be 2-12 letters or numbers';
  end if;
  if n ~ '(FUCK|SHIT|BITCH|CUNT|NIGGA|NIGGER|PUSSY|ASHAWO|OLOSHO|PORN|WHORE|RAPE)' then
    raise exception 'nickname not allowed';
  end if;
  return n;
end $$;

-- ---------- player profile ----------

create or replace function public.spk_register(p_nickname text, p_faction text) returns json
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); r public.players;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if not (p_faction = any (spk_factions())) then raise exception 'unknown faction'; end if;
  insert into players (id, nickname, faction)
  values (uid, spk_clean_nick(p_nickname), p_faction)
  on conflict (id) do update set nickname = excluded.nickname   -- re-registering never changes a locked faction
  returning * into r;
  return row_to_json(r);
end $$;

create or replace function public.spk_me() returns json
language sql stable security definer set search_path = public as $$
  select row_to_json(p) from players p where p.id = auth.uid()
$$;

-- Faction lock: 30 days per pick, with one free switch during the lock
create or replace function public.spk_switch_faction(p_faction text) returns json
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); r public.players;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if not (p_faction = any (spk_factions())) then raise exception 'unknown faction'; end if;
  select * into r from players where id = uid for update;
  if not found then raise exception 'not registered'; end if;
  if r.faction = p_faction then return row_to_json(r); end if;
  if r.locked_until > now() then
    if r.switches_left <= 0 then
      raise exception 'faction locked until %', to_char(r.locked_until, 'DD Mon');
    end if;
    update players set faction = p_faction, switches_left = switches_left - 1 where id = uid returning * into r;
  else
    update players set faction = p_faction, locked_until = now() + interval '30 days', switches_left = 1
    where id = uid returning * into r;
  end if;
  return row_to_json(r);
end $$;

-- ---------- leaderboards ----------

-- Factions ranked by average goals per match (min 10 counted matches); totals shown alongside
create or replace function public.spk_board(p_scope text default 'week')
returns table (faction text, matches bigint, goals bigint, avg_goals numeric, players bigint, rank bigint)
language sql stable security definer set search_path = public as $$
  with s as (
    select m.faction,
           count(*)                         as matches,
           sum(m.goals)::bigint              as goals,
           round(avg(m.goals)::numeric, 2)   as avg_goals,
           count(distinct m.player_id)       as players
    from matches m
    where m.counted and (p_scope = 'all' or m.week = spk_week())
    group by m.faction
  )
  select s.faction, s.matches, s.goals, s.avg_goals, s.players,
         case when s.matches >= 10
              then rank() over (partition by s.matches >= 10 order by s.avg_goals desc, s.goals desc) end
  from s
  order by (s.matches >= 10) desc, s.avg_goals desc, s.goals desc
$$;

create or replace function public.spk_top_players(p_scope text default 'week')
returns table (nickname text, faction text, matches bigint, goals bigint)
language sql stable security definer set search_path = public as $$
  select pl.nickname, pl.faction, count(*), sum(m.goals)::bigint
  from matches m join players pl on pl.id = m.player_id
  where m.counted and (p_scope = 'all' or m.week = spk_week())
  group by pl.id, pl.nickname, pl.faction
  order by sum(m.goals) desc, count(*) asc
  limit 20
$$;

-- ---------- submitting a finished match ----------
-- Goals are recomputed from the 5 shot results; at most one match every 12 seconds;
-- only the first 10 matches in any 24 hours count toward the board (the rest are practice).
create or replace function public.spk_submit(p_opponent text, p_mode text, p_results text) returns json
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  p public.players;
  last_at timestamptz;
  today int;
  g int;
  ok boolean;
  wk text := spk_week();
  pos bigint;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select * into p from players where id = uid;
  if not found then raise exception 'not registered'; end if;
  if p_results is null or p_results !~ '^[gsm]{5}$' then raise exception 'bad results'; end if;
  if not (p_opponent = any (spk_factions())) then raise exception 'unknown opponent'; end if;
  if p_mode not in ('solo', 'challenge', 'live') then raise exception 'bad mode'; end if;

  select max(created_at) into last_at from matches where player_id = uid;
  if last_at is not null and now() - last_at < interval '12 seconds' then raise exception 'too fast'; end if;

  g := char_length(p_results) - char_length(replace(p_results, 'g', ''));
  select count(*) into today from matches
  where player_id = uid and counted and created_at > now() - interval '24 hours';
  ok := today < 10;

  insert into matches (player_id, faction, opponent, mode, goals, results, counted, week)
  values (uid, p.faction, p_opponent, p_mode, g, p_results, ok, wk);

  select b.rank into pos from spk_board('week') b where b.faction = p.faction;
  return json_build_object('counted', ok, 'goals', g, 'faction', p.faction, 'rank', pos,
                           'left_today', greatest(0, 9 - today));
end $$;

-- ---------- who may call what ----------
revoke execute on function public.spk_register(text, text), public.spk_me(), public.spk_switch_faction(text),
  public.spk_submit(text, text, text), public.spk_board(text), public.spk_top_players(text) from public, anon;
grant execute on function public.spk_register(text, text), public.spk_me(), public.spk_switch_faction(text),
  public.spk_submit(text, text, text) to authenticated;
grant execute on function public.spk_board(text), public.spk_top_players(text) to anon, authenticated;
