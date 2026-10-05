-- Canonical Supabase/PostgreSQL schema. Apply in a new Supabase project.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 24),
  display_name text not null check (char_length(display_name) between 1 and 40),
  avatar_url text,
  level integer not null default 1 check (level >= 1),
  xp bigint not null default 0 check (xp >= 0),
  coins bigint not null default 0 check (coins >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.characters (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  description text not null default '',
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.player_characters (
  user_id uuid not null references public.profiles(id) on delete cascade,
  character_id uuid not null references public.characters(id) on delete cascade,
  unlocked boolean not null default false,
  mastery_level integer not null default 0 check (mastery_level >= 0),
  wins integer not null default 0 check (wins >= 0),
  losses integer not null default 0 check (losses >= 0),
  primary key (user_id, character_id)
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  player_1_id uuid references public.profiles(id) on delete set null,
  player_2_id uuid references public.profiles(id) on delete set null,
  winner_id uuid references public.profiles(id) on delete set null,
  player_1_character_id uuid references public.characters(id) on delete set null,
  player_2_character_id uuid references public.characters(id) on delete set null,
  game_mode text not null check (game_mode in ('offline', 'local', 'casual', 'ranked', 'online')),
  duration_seconds integer not null check (duration_seconds >= 0),
  player_1_rounds smallint not null check (player_1_rounds between 0 and 9),
  player_2_rounds smallint not null check (player_2_rounds between 0 and 9),
  created_at timestamptz not null default now(),
  check (winner_id is null or winner_id = player_1_id or winner_id = player_2_id)
);

create index if not exists matches_player_1_created_idx on public.matches (player_1_id, created_at desc);
create index if not exists matches_player_2_created_idx on public.matches (player_2_id, created_at desc);

create table if not exists public.rankings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  rating integer not null default 1000 check (rating >= 0),
  wins integer not null default 0 check (wins >= 0),
  losses integer not null default 0 check (losses >= 0),
  rank_tier text not null default 'rookie',
  updated_at timestamptz not null default now()
);

create table if not exists public.match_audit (
  id bigint generated always as identity primary key,
  match_id uuid not null,
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.settle_verified_match(
  p_match_id uuid,
  p_player_1_id uuid,
  p_player_2_id uuid,
  p_winner_id uuid,
  p_player_1_rounds smallint,
  p_player_2_rounds smallint,
  p_duration_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  inserted_count integer;
  loser_id uuid;
begin
  if p_player_1_id is null
    or p_player_2_id is null
    or p_winner_id is null
    or p_player_1_id = p_player_2_id
    or p_winner_id not in (p_player_1_id, p_player_2_id)
    or greatest(p_player_1_rounds, p_player_2_rounds) <> 2
    or p_player_1_rounds = p_player_2_rounds
    or (p_player_1_rounds > p_player_2_rounds and p_winner_id <> p_player_1_id)
    or (p_player_2_rounds > p_player_1_rounds and p_winner_id <> p_player_2_id)
    or p_duration_seconds < 1
    or p_duration_seconds > 1800 then
    raise exception 'invalid verified match';
  end if;

  insert into public.matches (
    id, player_1_id, player_2_id, winner_id, game_mode,
    duration_seconds, player_1_rounds, player_2_rounds
  ) values (
    p_match_id, p_player_1_id, p_player_2_id, p_winner_id, 'online',
    p_duration_seconds, p_player_1_rounds, p_player_2_rounds
  ) on conflict (id) do nothing;

  get diagnostics inserted_count = row_count;
  if inserted_count = 0 then
    return false;
  end if;

  loser_id := case when p_winner_id = p_player_1_id then p_player_2_id else p_player_1_id end;

  insert into public.rankings (user_id) values (p_winner_id), (loser_id)
  on conflict (user_id) do nothing;

  update public.rankings
  set rating = rating + 25,
      wins = wins + 1,
      rank_tier = case
        when rating + 25 >= 1800 then 'legend'
        when rating + 25 >= 1500 then 'elite'
        when rating + 25 >= 1200 then 'contender'
        else 'rookie'
      end
  where user_id = p_winner_id;

  update public.rankings
  set rating = greatest(0, rating - 20),
      losses = losses + 1,
      rank_tier = case
        when greatest(0, rating - 20) >= 1800 then 'legend'
        when greatest(0, rating - 20) >= 1500 then 'elite'
        when greatest(0, rating - 20) >= 1200 then 'contender'
        else 'rookie'
      end
  where user_id = loser_id;

  insert into public.match_audit (match_id, event_type, details)
  values (p_match_id, 'settled', jsonb_build_object('winner_id', p_winner_id));

  return true;
end;
$$;

revoke all on function public.settle_verified_match(uuid, uuid, uuid, uuid, smallint, smallint, integer) from public, anon, authenticated;
grant execute on function public.settle_verified_match(uuid, uuid, uuid, uuid, smallint, smallint, integer) to service_role;

create or replace function public.touch_updated_at()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    'player_' || left(replace(new.id::text, '-', ''), 16),
    left(coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'New Fighter'), 40)
  );
  insert into public.rankings (user_id) values (new.id);
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists rankings_touch_updated_at on public.rankings;
create trigger rankings_touch_updated_at before update on public.rankings
for each row execute function public.touch_updated_at();

alter table public.profiles enable row level security;
alter table public.characters enable row level security;
alter table public.player_characters enable row level security;
alter table public.matches enable row level security;
alter table public.rankings enable row level security;
alter table public.match_audit enable row level security;

drop policy if exists "profiles readable" on public.profiles;
create policy "profiles readable" on public.profiles for select using (true);
drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

drop policy if exists "active characters readable" on public.characters;
create policy "active characters readable" on public.characters for select using (is_active);

drop policy if exists "users read own unlocks" on public.player_characters;
create policy "users read own unlocks" on public.player_characters for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "players read own matches" on public.matches;
create policy "players read own matches" on public.matches for select to authenticated
using ((select auth.uid()) = player_1_id or (select auth.uid()) = player_2_id);

drop policy if exists "rankings readable" on public.rankings;
create policy "rankings readable" on public.rankings for select using (true);

-- Deliberately no client INSERT policies for matches/rankings/unlocks/profiles. Trusted code writes them.
revoke all on public.profiles, public.characters, public.player_characters, public.matches, public.rankings, public.match_audit from anon, authenticated;
grant usage on schema public to anon, authenticated;
grant select on public.characters, public.rankings to anon, authenticated;
grant select on public.profiles to anon, authenticated;
grant update (username, display_name, avatar_url) on public.profiles to authenticated;
grant select on public.player_characters, public.matches to authenticated;

