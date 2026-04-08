# President Prototype

Mobile-first local prototype of the card game President, built with a clean `client` / `server` / `shared` split so the rules engine can stay authoritative as the project grows toward multiplayer.

## Stack

- Client: Phaser 3 + TypeScript + Vite
- Server: Node.js + Express + TypeScript
- Shared: card models, rules config, and API/state types

## Quick Start

```bash
npm install
npm run dev
```

This starts:

- client on `http://localhost:5173`
- server on `http://localhost:3001`

## Current Scope

- 1 human player plus naive bots
- 52-card deck
- Single / pair / triple / four-of-a-kind plays
- Turn validation and pile reset rules
- Starting player chosen from the player holding `3 of Clubs`
- Simple mobile-first portrait table UI
- Central pile, action buttons, event log, and turn indicators

## Architecture Notes

- `shared/src`: stable domain types and card helpers
- `server/src/game`: authoritative round engine, move validation, bot behavior, and turn advancement
- `server/src/app.ts`: minimal REST API for local/dev play
- `client/src/api`: server communication
- `client/src/game/scenes`: Phaser scenes only
- `client/src/game/layout.ts` and `client/src/game/theme.ts`: UI structure and styling knobs for future visual redesigns

## API

- `POST /game`: reset and deal a fresh local game
- `GET /game`: fetch current public state for the human player
- `POST /game/action`: submit `{ type: "play", playerId, cardIds }` or `{ type: "pass", playerId }`

## Future Extension Points

- TODO: replace the in-memory game manager with room/session management
- TODO: add websocket push for real multiplayer turn updates
- TODO: add round-to-round role exchange and configurable house rules
- TODO: swap placeholder visuals for Stitch-driven layout/theme components without touching server rules
