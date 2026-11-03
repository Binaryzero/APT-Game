# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Packet Tactics: an original turn-based cybersecurity card game built with **Godot 4.7.2** (standard non-.NET edition, GL Compatibility renderer). Play modes are local AI opponents and same-device Hot Seat; there is no game backend. The game is an original adaptation inspired by the *Advanced Persistent Threat* rulebook — do not copy official rulebook text, card names, or art.

## Commands

Godot must be on `PATH` (or set `GODOT_BIN`). The project must be imported once by the editor (or by the `--editor --import` step `npm test` runs) before headless scripts work.

```sh
godot --path .                          # run the game (main scene: scenes/boot.tscn)
npm test                               # import project + run all four PT test layers
npm run test:smoke                     # card art mappings and initial state
npm run test:ui                        # UI interaction checks
npm run test:engine                    # 122 deterministic AI matches + 48 deck-exhaustion scenarios
npm run test:layout                    # UI adapts to 7 window sizes/aspect ratios
npm run export:web                     # headless Web export to dist/
python3 -m http.server 8000 --directory dist   # serve the Web build (don't open index.html directly)
```

Run any single headless test directly — tests are `SceneTree` scripts, not a test framework:

```sh
godot --headless --path . --script res://test/pt_engine_test.gd
godot --headless --path . --script res://test/boot_loading_test.gd
```

Other test files in `test/` follow the same pattern (e.g. `pt_capture.gd`, `pt_capture2.gd` screenshot drivers).

There is no linter.

## Architecture

### Game core

- `scripts/pt/pt_defs.gd` — static content: all card definitions (133-card deck plus per-player starter Staging Server), card types (`stage`/`prod`/`soft`/`mal`/`exploit`/`zd`), win/hand constants.
- `scripts/pt/pt_engine.gd` — authoritative rules engine, **no UI code**. Decisions are requested from per-seat "brains" and may be awaited, so the same engine runs headless in tests. Owns deck, players, turn phases, the 0DAY response stack, and win/deck-exhaustion resolution.
- `scripts/pt/pt_ai.gd` — deterministic AI: decisions are pure functions of visible state; a per-seat seeded RNG is used only for the Rock-Paper-Scissors tiebreaker, so replays are reproducible.
- `scripts/pt/pt_human.gd` — human brain that awaits decisions from the UI.
- `scripts/pt/pt_game.gd` — main scene (`scenes/packet_tactics.tscn`): builds the table UI, runs the engine, answers human decisions, hot-seat privacy curtain.
- `scenes/boot.tscn` + `scripts/boot.gd` — lightweight boot scene (configured main scene) that renders a loading screen, then loads `packet_tactics.tscn`.

There are no autoloads; all modules are preloaded explicitly.

### UI scaling

The UI is built in code on a 1280×720 design grid. The project stretches with `canvas_items` + aspect **`expand`** + HiDPI on and opens maximized: Godot keeps a uniform element scale and grows the *design viewport* along the excess axis (1920×1200 window → 1280×800 viewport; 3440×1440 → 1720×720), so element sizes stay in design pixels and there are no letterbox bars. `scripts/pt/pt_layout.gd` (`PtLayout.metrics()`) is the single source of region geometry — each screen recomputes positions from the live viewport in an `_apply_layout()`/`_relayout()` connected to `size_changed`. Keep new UI code in design pixels and derive positions from `PtLayout`, never from absolute 1280×720 coordinates.

When changing engine behavior, keep `test/pt_engine_test.gd` green: it asserts card conservation, unique card IDs, placement rules, deterministic replays, card coverage, and deck-exhaustion outcomes.

### Localization

`scripts/localization.gd` (class `EmberpanL10n`) reads `localization/en.json` and `localization/zh-CN.json`. Only the five `loading.*` boot-screen keys live in the catalogs; the game's in-game text is hardcoded English. The two catalogs must keep identical key sets.

### Web build, site, and dashboard

- `export_presets.cfg` holds the `Web` preset; `npm run export:web` writes to `dist/`.
- `site/` is the **published** Web build and sharing assets — generated output, not hand-edited source.
- `dashboard/` is a static status page deployed to GitHub Pages on every successful `main` push.
- `coverage/latest.json` is a behavioral-coverage snapshot **auto-committed by CI** ("Update behavioral coverage snapshot [skip ci]" commits) — don't hand-edit it.

### CI and releases

`.github/workflows/game-ci.yml` runs on PRs and pushes to `main`: installs Godot 4.7.2 + Web export templates, runs `npm test`, regenerates `coverage/latest.json` (committed back to `main`), exports the Web build as an artifact, and deploys the dashboard. Pushing a tag `v*` additionally creates a GitHub Release with `PacketTactics-Web.zip`. Releases are tag-driven — there is no other release switch.