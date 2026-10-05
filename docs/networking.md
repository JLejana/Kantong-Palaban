# Networking

## Why not Supabase realtime combat

Supabase is used for accounts and durable records, not frame-by-frame fighting. Combat inputs arrive around 60 times per second, are latency-sensitive, and require ordering, prediction, validation, and eventually rollback. Database rows or realtime table changes are the wrong authority and add unnecessary latency and cost.

## WebSocket release-candidate transport

The Node service authenticates a guest or Supabase session, assigns a resumable player identity, manages lobbies/ready state and a queue, then relays frame-numbered input inside a two-player room. It rejects malformed/oversized messages, origin violations, rate excess, identity mismatches, duplicate/out-of-order frames, implausibly large frame jumps, and conflicting result reports. WebSocket is available in browser, desktop, and mobile builds.

Authenticated results are persisted only after both players agree, then settled atomically through a server-only Supabase function. Guest results are intentionally ephemeral. This is casual networking rather than ranked anti-cheat: a malicious pair can collude, so ranked play must add authoritative simulation or signed replay verification.

## Optional WebRTC

The Godot WebRTC client creates an unordered/unreliable combat data channel and handles offer, answer, and ICE events. The WebSocket server provides room-checked signaling. WebSocket remains the default because production peer-to-peer play also needs TURN credentials, platform-native WebRTC support, privacy review, and abuse controls.

## Rollback core

For simulation frame `N`, each peer stores local and remote input plus a complete serializable snapshot. If remote input is missing, the client predicts it, usually by repeating the last direction/buttons. When the real input differs, it restores the snapshot before the earliest mismatch and resimulates through the current frame.

The implemented rollback core provides:

1. bounded local/remote frame histories;
2. repeat-last-input prediction and mismatch signals;
3. fighter state snapshots;
4. configurable input delay and retention; and
5. generic restore/resimulation callbacks covered by a headless test.

The release-candidate match uses input delay instead of automatic rewind. Enabling deterministic rewind requires replacing nondeterministic CharacterBody collision outcomes with a deterministic simulation adapter and suppressing audiovisual side effects during resimulation.

