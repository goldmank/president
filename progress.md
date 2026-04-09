Original prompt: Build a playable skeleton for a mobile-first card game app based on the game "President" (also known as Asshole / Scum). Tech stack: client Phaser 3 + TypeScript, server Node.js + TypeScript, clean client/server architecture, local playable prototype first, strong separation between visuals and game logic, one human + naive bots, portrait-first responsive UI, simple polished extendable design.

2026-04-08
- Workspace was empty; scaffolding full project from scratch.
- Using a monorepo-style setup with `client`, `server`, and `shared`.
- Priority is correctness and clean separation: rules on server, Phaser as rendering/input shell.
- Verification found initial TS project-reference issue; fixing composite build wiring before deeper runtime checks.
- Runtime validation hit a Vite bind issue on `::1`; forcing dev server host to `127.0.0.1`.
- Added workspace-local VS Code MCP config for Stitch in `.vscode/mcp.json`.
- TODO: add deterministic browser smoke test hooks and run a full local verification loop after implementation.
- Added DOM-driven results overlay and Stitch-style Power Shift section.
- Added DOM-driven exchange overlay with selectable hand cards, role-based required card counts, results-to-exchange flow, and mock exchange entry points via `?mockExchange=1`, `X`, and `window.toggleMockExchange()`.
- Added animated hand selection lift/scale and a client-side play-card flight from the hand to the center pile before the server action resolves.
- Replaced opponent card-count badges with inward-facing face-down hand fans and added bot play-card flight from those seat hands to the center pile.
- Added Joker as a new highest rank above `2` and expanded the deck to include two Jokers, with shared/server/client label and rendering updates.
- Added Capacitor Android wrapper under `client/android`, enabled cleartext HTTP for local device testing, switched default API base URL to `127.0.0.1:3001`, and added root/client Android helper scripts. Built and installed debug APK to a USB-connected device using `adb reverse tcp:3001 tcp:3001`.
- Replaced live per-card text/shape rendering with cached generated card-face textures (`normal` / `selected` / `disabled`) so cards are generated once and reused as images across hand and table rendering. This is aimed at improving Android sharpness and reducing per-card render cost.
- TODO: wire the exchange overlay to real server-side exchange state/actions instead of preview/mock-only behavior.
- Verification note: `npm run typecheck -w client` and `npm run build -w client` pass. Browser automation is still blocked in this environment; `npx playwright --version` hangs instead of returning a local version.
