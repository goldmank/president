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
- TODO: wire the exchange overlay to real server-side exchange state/actions instead of preview/mock-only behavior.
