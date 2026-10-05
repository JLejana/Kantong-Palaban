# Combat design

Combat advances on Godot's fixed 60 Hz physics tick. Each fighter owns a small state machine with: `idle`, `walk_forward`, `walk_backward`, `crouch`, `jump`, `attack`, `block`, `hit_stun`, `block_stun`, `knockdown`, `get_up`, and `ko`.

An attack resource contains startup, active, and recovery frame counts. Startup telegraphs the move, active frames enable its hitbox, and recovery delays the fighter's return to neutral. A hit applies health loss, knockback, and hit stun. A valid block applies chip damage and shorter block stun. Knockdown attacks transition through knockdown and get-up before returning to neutral.

Hitboxes are monitoring `Area2D` nodes on the hitbox collision layer. Hurtboxes are monitorable areas on a separate layer. A hitbox clears its hit registry when activated and therefore cannot repeatedly damage the same target during one attack unless the attack explicitly permits it. F6 toggles Godot collision visualization and the state/frame overlay.

Input edges are stored for a short frame window and normalized relative to facing direction. The release rules recognize basic attacks plus forward+RP, down+LK, simultaneous LP+RK, and retain enough ordered history for sequences such as LP, LP, RK. Charge moves, diagonals, and character-specific command lists are deliberately outside this two-character ruleset.

The combo counter records confirmed unblocked hits within a timeout, drives the HUD, and applies a 10% per-hit damage reduction down to a 40% floor. Character-specific cancel trees are outside this two-character release-candidate ruleset.

Each fighter resource also owns its color palette, silhouette style, damage multiplier, and optional command attacks. `FighterA` uses a quick Skyline Strike while `FighterB` uses the slower knockdown-oriented Court Crusher. Confirmed hits drive visual-only sparks, flashes, camera shake, controller vibration, and short offline hit-stop; online simulation does not add local-only hit-stop.

