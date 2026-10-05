# Bayan Brawl release-candidate foundation

An original, cross-platform Filipino-inspired 2D fighting game built with Godot 4 and GDScript. The repository uses fictional development characters (`FighterA` and `FighterB`), original primitive visuals, and user-supplied character artwork. It contains no third-party fighting-game characters, trademarks, or catchphrases.

The release-candidate flow includes a main menu, CPU and local-versus modes, character/stage selection, saved settings, guest or Supabase-authenticated online play, public matchmaking, private lobbies, reconnect support, and best-of-three combat.

## Requirements

- Godot 4.7.2 or newer with platform export templates
- Node.js 20 or newer for the multiplayer service
- Optional: Supabase project and Supabase CLI for accounts and persistence
- Android: Android SDK plus JDK 17
- iOS: macOS, Xcode, and an Apple Developer signing team

## Run the game

1. Import `game/project.godot` in Godot.
2. Press F6/F5 to open the main menu.
3. Choose VS CPU, Local Versus, or Online.

Choose Character Test to open the training/debug mode. It starts immediately with a passive dummy, infinite time, a character-specific move list, and automatic dummy recovery after KO. Press R to reset the session.

Player 1 uses A/D, W/S, U/I, J/K, and L. Player 2 uses the arrow keys, number-row 1/2/3/4, and 0. Two gamepads are supported by default: left stick/D-pad for movement, face buttons for attacks, and the right shoulder button for block. Controls can be rebound from Settings. R restarts offline matches, F6 toggles debug information, F7 switches CPU/local mode during an offline fight, and Escape returns to the menu. Touch controls, screen shake, and vibration are configurable.

## Fighter sprite sheets

Fighter A currently has `idle`, `walk_forward`, `walk_backward`, `crouch`, `block`, `crouch_block`, and `jump` animations. Each runtime sheet is a transparent 2048x1024 PNG arranged as four columns by two rows, read left-to-right and then top-to-bottom. The eight 512x512 cells share a fixed foot baseline. The original generated sheets remain in `game/fighters/fighter_a/animations`; runtime-ready copies are in its `normalized` subfolder.

To normalize another two-row/eight-pose sheet without resizing its poses:

```powershell
./tools/normalize_animation_sheet.ps1 `
  -InputPath "game/fighters/fighter_a/animations/idle.png" `
  -OutputPath "game/fighters/fighter_a/animations/normalized/idle.png"
```

Add the normalized texture to `animation_sheets` in `fighter_a.tres` using a state or attack animation name, and optionally add its playback speed to `animation_fps`. Missing animations safely fall back to `idle`; walking backward reuses `walk_forward` in reverse.

## Run the multiplayer server

```powershell
cd server
Copy-Item .env.example .env
npm install
npm run typecheck
npm test
npm run dev
```

The default URL is `ws://127.0.0.1:8080`. The server provides:

- guest sessions or verified Supabase access tokens;
- identity-preserving reconnect tokens with a configurable grace window;
- lobby creation/joining, ready state, and public queue pairing;
- ordered, identity-bound combat input relay;
- message-size, origin, schema, frame-order, and rate validation;
- optional WebRTC offer/answer/ICE signaling;
- two-party match-result consensus;
- atomic server-only Supabase match/rating settlement; and
- periodic operational counters.

Set `REQUIRE_AUTH=true` to disable guest matchmaking. Production should expose the server as `wss://` behind TLS. A single server process owns its rooms; horizontal scaling requires sticky sessions or an external room coordinator.

## Runtime configuration

For local desktop development, environment variables override public configuration:

- Client: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MULTIPLAYER_URL`
- Server: the variables documented in `server/.env.example`

For Web/mobile exports, edit `game/data/backend/public_config.json`. A Supabase anon key is designed to be public and is constrained by RLS. Never put the service-role key in the Godot project, public JSON, or exported client.

## Supabase

1. Create a Supabase project.
2. Apply `database/schema.sql` or the equivalent standalone migration.
3. Apply the launch-roster seed in `database/seed/001_characters.sql`.
4. Configure the public URL/anon key in the client and the service-role key only on the server.

The schema creates signup profiles/rankings, RLS policies, restricted column grants, match audit records, and `settle_verified_match`. Only the service role can execute match settlement; clients cannot write rankings, currency, XP, unlocks, or match outcomes.

## Networking model

WebSocket is the active release-candidate transport. Combat inputs carry simulation frame numbers and are applied through a small input-delay window. The rollback module stores local/remote history, predicts absent input, detects mispredictions, retains snapshots, bounds rollback distance, and exposes restore/resimulation callbacks. This core is tested independently; the current CharacterBody-based match deliberately uses input delay rather than enabling cross-platform deterministic rewind.

The optional WebRTC client and server signaling route are available for later transport selection without changing combat messages. Native platforms may require Godot's platform WebRTC support/plugin and a production TURN service.

## Export

Export presets are provided for Web, Android, Windows Desktop, and iOS.

Web:

```powershell
./tools/build_web.ps1 -GodotExecutable "C:\path\to\godot.exe"
npx wrangler pages deploy build/web --project-name=bayan-brawl
```

The build script performs a release export, copies Cloudflare response headers, and verifies the HTML, JavaScript, WebAssembly, PCK, and headers output. Matching Godot export templates must be installed. Cloudflare Pages hosts only the static client; deploy the WebSocket service separately. No live deployment is performed automatically.

Android requires local SDK/JDK configuration and a release keystore. iOS export/signing must run on macOS with Xcode and your Apple team. The committed application identifier is `com.bayanbrawl.game`; verify ownership before store submission.

## Validation

```powershell
godot --headless --path game --scene res://tests/parse_all.tscn
godot --headless --path game --scene res://tests/ui_smoke_test.tscn
godot --headless --path game --scene res://tests/combat/smoke_test.tscn
godot --headless --path game --scene res://tests/combat/training_test.tscn
godot --headless --path game --scene res://tests/networking/rollback_test.tscn
godot --headless --path game --scene res://tests/polish_test.tscn

cd server
npm run typecheck
npm test
```

The WebSocket test verifies authentication, reconnect identity, matchmaking, spoof rejection, input relay, ping, conflicting-result rejection, and result consensus.

## Implemented systems

- Data-driven reusable fighters and attacks
- Fixed-tick startup/active/recovery timing
- Hitboxes, hurtboxes, blocking, chip damage, stun, knockback, knockdown, KO
- Buffered commands, combo tracking, damage scaling, and combo HUD
- Distinct data-driven fighter silhouettes, damage profiles, and forward+RP special attacks
- Hit sparks, fighter flashes, hit-stop, camera shake, controller vibration, and animated combo feedback
- 99-second best-of-three rounds and timeout resolution
- Weighted easy/normal/hard CPU state machine
- Rebindable keyboard/two-gamepad controls and landscape touch controls
- Functional menus, accessibility settings, career screen, and platform helpers
- Supabase registration, login, session refresh, logout, profile, history, and rankings clients
- Hardened TypeScript multiplayer server and optional WebRTC signaling
- Frame histories, snapshot retention, prediction detection, and generic bounded resimulation
- Web, Android, Windows, and iOS export presets

See `docs/architecture.md`, `docs/combat-design.md`, `docs/networking.md`, and `docs/database.md` for design details.

