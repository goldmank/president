# President Flutter App

This directory contains the Flutter client for the President card game. It is the newer mobile app that replaced the older Phaser-based client in the root `client/` package.

## What This App Does

The app is a portrait-first game client for a local President match:

- renders the table, player seats, avatars, hand, pile, and result overlays
- lets the human player select cards, play, or pass
- animates cards from the hand or opponent seats to the table
- drives bot turns by calling the backend when the active player is a bot
- shows end-of-round results and exchange UI

The app does not contain the authoritative game rules. The Node.js server in the repo root is the source of truth for game state, move validation, turn order, and bot logic.

## High-Level Architecture

- `lib/main.dart`
  Starts Flutter, locks orientation to portrait, and launches the app shell.

- `lib/src/app_shell.dart`
  Creates `MaterialApp`, applies the shared theme, and mounts the main game screen.

- `lib/src/game_screen.dart`
  Main screen and orchestration layer. Handles:
  - initial game load
  - local UI state such as selected cards and banners
  - play/pass actions
  - bot turn scheduling
  - viewer-hand and table animations
  - results and exchange overlays

- `lib/src/game_api.dart`
  Thin HTTP client for the backend API.

- `lib/src/models.dart`
  Dart models for public game state, cards, players, actions, and helper labels.

- `lib/src/card_asset.dart`
  Card-face rendering and shared card sizing constants.

- `lib/src/game_overlays.dart`
  Match results and exchange overlays.

- `lib/src/president_theme.dart`
  Shared colors and Material styling.

## Assets

- `assets/cards/white/`
  Card art assets still included in the app package, though the current card face is rendered in Flutter widgets.

- `assets/default_avatar.svg`
  Default avatar used for player seats. The app places this dark SVG on top of a player-color filled circle.

## How The App Connects To The Server

The app talks to the Node.js backend over HTTP through `GameApi`.

Default base URL:

```dart
https://assad.ngrok.dev
```

This is defined in `lib/src/game_api.dart` via a compile-time environment value:

```dart
const String.fromEnvironment('SERVER_URL', defaultValue: 'https://assad.ngrok.dev')
```

That means you can point the app at another backend without editing code by passing `--dart-define`.

Example:

```bash
flutter run --dart-define=SERVER_URL=http://10.0.2.2:3001
```

Useful local examples:

- Android emulator to local host machine: `http://10.0.2.2:3001`
- iOS simulator to local host machine: `http://127.0.0.1:3001`
- physical device on same network: `http://<your-lan-ip>:3001`
- tunnel / remote server: `https://<your-domain-or-ngrok-host>`

## Backend API Used By The App

The Flutter app currently uses these endpoints:

- `POST /game`
  Creates a fresh game and returns the full public state for the viewer.

- `POST /game/action`
  Sends either:
  - `{ "type": "play", "playerId": "...", "cardIds": [...] }`
  - `{ "type": "pass", "playerId": "..." }`

- `POST /game/bot-turn`
  Asks the server to execute the next bot move.

- `POST /game/fast-forward`
  Advances the game to the end. Mainly useful for debugging/dev flows.

Responses are decoded into `PublicGameStateModel`.

## Runtime Flow

1. The app starts and `GameScreen` calls `createGame()`.
2. The server returns the public game state.
3. The app renders the seats, pile, hand, and action button from that state.
4. When the user taps cards, selection is handled locally in Flutter.
5. When the user presses play or pass, the app sends the action to the server.
6. The server validates the move, mutates game state, and returns the new public state.
7. The app updates the UI from the server response.
8. If the new current player is a bot, the app schedules a call to `POST /game/bot-turn`.

Important detail:

- the Flutter client is a stateful renderer and interaction layer
- the server is authoritative
- any move legality must be considered server-owned even if the client already disables obviously invalid plays

## Running The App

Install dependencies:

```bash
flutter pub get
```

Run with the default backend:

```bash
flutter run
```

Run against a specific backend:

```bash
flutter run --dart-define=SERVER_URL=http://10.0.2.2:3001
```

## Development Notes

- The app assumes portrait play and sets portrait orientation at startup.
- A lot of presentation behavior lives in `game_screen.dart`; this is the main file to inspect for gameplay UI changes.
- The app contains local animation state that temporarily diverges from server state for visual smoothness, but the final source of truth always comes from the backend response.
- Client-side errors are logged with context tags such as `submit_action`, `bot_turn`, and `load_game` to help debug transient failures.

## Relationship To The Rest Of The Repo

- `app/`
  Flutter mobile client

- `server/`
  Node.js + Express game backend

- `shared/`
  Shared TypeScript domain model used by the server and legacy TS client

- `client/`
  Older Phaser/Capacitor client kept in the repo as the previous implementation
