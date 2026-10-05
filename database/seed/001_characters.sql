insert into public.characters (id, slug, name, description, is_active)
values
  ('00000000-0000-4000-8000-000000000001', 'fighter-a', 'FighterA', 'Original launch-roster fighter.', true),
  ('00000000-0000-4000-8000-000000000002', 'fighter-b', 'FighterB', 'Original launch-roster fighter.', true)
on conflict (slug) do update set name = excluded.name, description = excluded.description, is_active = excluded.is_active;
