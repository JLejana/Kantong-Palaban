# Architecture

The repository has three runtime boundaries. They deliberately do not share responsibilities.

## Godot client

`game/` owns 60 Hz combat, rendering, input, touch controls, local match rules, menu/session flow, and CPU behavior. `Fighter` is reusable; character scenes supply `FighterStats` resources containing balance and visual identity. Attacks are `AttackData` resources. UI and combat feedback observe fighter and round signals instead of calculating combat outcomes. Saved settings include accessibility options and per-device control overrides.

The local game remains playable without an account or network. Platform helpers keep mobile/web checks outside combat. The active transport is replaceable so WebRTC can be selected without changing fighter logic.

## Supabase

Supabase owns identity and durable, non-realtime player data: profiles, unlocks, match history, and rankings. The browser/mobile client uses only the public anon key plus a user access token. Row Level Security restricts each user to appropriate records.

Clients cannot write authoritative match records, ranking changes, unlocks, or progression. Those writes belong to trusted server code using a service-role key that must never ship in a game export.

## Multiplayer server

`server/` is a strict TypeScript WebSocket service. It accepts connections, creates two-player lobbies, tracks readiness, pairs a queue, creates rooms, validates monotonically increasing input frames, relays inputs, and accepts match-result messages. It does not treat Supabase as a realtime bus.

The server verifies Supabase tokens when supplied, supports configurable guest access, rate-limits clients, bounds payloads, preserves identity during short reconnects, rejects spoofed/out-of-order inputs, requires matching result reports, and writes authenticated results through an atomic service-role RPC. It is suitable for casual release-candidate testing, not authoritative ranked play: ranked mode would require server simulation or replay verification plus an external room coordinator for multi-instance deployment.

## Rollback and input delay

The client separates frame-tagged input, snapshot containers, and transport. `RollbackManager` retains inputs/snapshots, predicts remote input, detects mismatches, and exposes bounded restore/resimulation callbacks. The active CharacterBody match uses a three-frame input-delay strategy because Godot physics is not guaranteed deterministic across all targets. See [networking.md](networking.md).

