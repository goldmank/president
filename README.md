# President

This repository contains a local-play prototype of the card game President. The current codebase is split between a Flutter client port, an older Phaser client, a Node.js server, and a shared TypeScript game model package.

## Project Structure

### `app/`

Flutter client. This is the newer client after the port away from Phaser.

- `app/lib/main.dart`: Flutter entrypoint; locks the app to portrait and boots `PresidentApp`.
- `app/lib/src/app_shell.dart`: top-level `MaterialApp` shell and theme wiring.
- `app/lib/src/game_screen.dart`: main gameplay screen; owns local UI state, card selection, animations, bot-turn polling, overlays, and calls to the backend.
- `app/lib/src/game_api.dart`: HTTP client for the server endpoints such as `/game`, `/game/action`, `/game/bot-turn`, and `/game/fast-forward`.
- `app/lib/src/models.dart`: Dart-side API models and payloads mirroring the server's public game state.
- `app/lib/src/game_overlays.dart`: end-of-round hierarchy and exchange UI.
- `app/lib/src/card_asset.dart`: card image mapping plus the custom Joker card widget.
- `app/lib/src/president_theme.dart`: shared colors and Material theme setup.
- `app/assets/cards/white/`: raster card-face assets used by the Flutter UI.
- `app/android`, `app/ios`, `app/linux`, `app/windows`, `app/web`: standard Flutter platform runners generated for each target.

### `server/`

Node.js + Express backend. This is the authoritative game engine for local matches.

- `server/src/index.ts`: server bootstrap; binds the Express app to port `3001` by default.
- `server/src/app.ts`: HTTP routes and middleware.
- `server/src/game/GameManager.ts`: in-memory game lifecycle wrapper around a single active match.
- `server/src/game/presidentEngine.ts`: core game rules, dealing, move validation, turn progression, bot actions, finishing order, and public-state projection.
- `server/src/game/random.ts`: shuffle/time helpers used by the engine.
- `server/dist/`: compiled output from the TypeScript build.

### `shared/`

Shared TypeScript package consumed by the server and the older TypeScript client.

- `shared/src/card.ts`: card definitions, deck construction, rank labels, and card helpers.
- `shared/src/rules.ts`: game configuration and defaults.
- `shared/src/game.ts`: authoritative TypeScript types for game state, public state, actions, pile state, and results.
- `shared/src/index.ts`: barrel exports.
- `shared/dist/`: built package output.

### `client/`

Legacy Phaser 3 + Vite + Capacitor client from before the Flutter port. It is still present in the repo and the root npm scripts still point at it.

- `client/src/main.ts`: Phaser bootstrap, DOM overlays, and debug/render diagnostics.
- `client/src/game/scenes/GameScene.ts`: primary gameplay scene, input handling, animations, bot stepping, and render orchestration.
- `client/src/api/GameApi.ts`: fetch wrapper for the same server API used by the Flutter app.
- `client/src/game/`: Phaser-specific presentation code such as layout, textures, objects, theme, and text rendering.
- `client/src/results/`: DOM overlays for results and exchange flows.
- `client/public/cards/white/`: card textures used by the web/Capacitor client.
- `client/android/`: Capacitor Android wrapper for the legacy client.
- `client/dist/`: built web output.

### Root Files

- `package.json`: npm workspace config for `shared`, `server`, and the legacy `client`.
- `tsconfig.base.json`: base TypeScript configuration shared by the TS packages.
- `progress.md`: implementation notes from the original Phaser-based buildout and later changes.
- `stitch_downloads/`: design/reference artifacts generated during UI work.

## How The Pieces Fit Together

- The server owns the actual rules and match state.
- The Flutter app in `app/` is the current client port and talks to the server over HTTP.
- The shared TS package defines the game contracts for the server and the old TS client.
- The Phaser client remains as a legacy implementation and reference while the Flutter port is being developed.

## Current Repo Reality

- If you run root-level `npm` scripts, you are working with `server/`, `shared/`, and the legacy `client/`.
- The Flutter app in `app/` is separate from that npm workspace and is managed with normal Flutter tooling.
- Some backend contract details still reflect the original TS implementation, while the Flutter app mirrors them manually in Dart models.
