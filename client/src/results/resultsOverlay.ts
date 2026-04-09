import type { PublicGameState, PublicPlayerState } from "@president/shared";
import { palette } from "../game/theme";
import { enableDragScroll } from "./dragScroll";

type ResultsMode = "finished" | "mock";

export interface ResultsEntry {
  playerId: string;
  name: string;
  avatarColor: string;
  place: number;
  role: string;
  points: number;
  isViewer: boolean;
}

export interface PowerShift {
  leftRole: string;
  rightRole: string;
  cardsLabel: string;
  leftAvatarColor: string;
  rightAvatarColor: string;
  leftInitials: string;
  rightInitials: string;
}

export interface MatchResultsData {
  mode: ResultsMode;
  title: string;
  subtitle: string;
  entries: ResultsEntry[];
  shifts: PowerShift[];
  actionLabel: string;
  footerText: string;
}

function roleForPlace(place: number, total: number): string {
  if (place === 1) {
    return "President";
  }

  if (place === 2) {
    return "Vice President";
  }

  if (place === total) {
    return "Scum";
  }

  if (place === total - 1 && total >= 4) {
    return "Vice Scum";
  }

  return "Citizen";
}

function scoreForPlace(place: number): number {
  return Math.max(240, 1240 - (place - 1) * 220);
}

function initialFromName(name: string): string {
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join("");
}

function compareResults(left: ResultsEntry, right: ResultsEntry): number {
  return left.place - right.place;
}

function buildShifts(entries: ResultsEntry[]): PowerShift[] {
  const findEntry = (role: string): ResultsEntry | undefined => entries.find((entry) => entry.role === role);
  const president = findEntry("President");
  const scum = findEntry("Scum");
  const vice = findEntry("Vice President");
  const viceScum = findEntry("Vice Scum");
  const shifts: PowerShift[] = [];

  if (president && scum) {
    shifts.push({
      leftRole: "PRES",
      rightRole: "SCUM",
      cardsLabel: "2 Best Cards",
      leftAvatarColor: president.avatarColor,
      rightAvatarColor: scum.avatarColor,
      leftInitials: initialFromName(president.name),
      rightInitials: initialFromName(scum.name)
    });
  }

  if (vice && viceScum) {
    shifts.push({
      leftRole: "VICE",
      rightRole: "V. SCUM",
      cardsLabel: "1 Best Card",
      leftAvatarColor: vice.avatarColor,
      rightAvatarColor: viceScum.avatarColor,
      leftInitials: initialFromName(vice.name),
      rightInitials: initialFromName(viceScum.name)
    });
  }

  return shifts;
}

function buildEntriesFromPlayers(players: PublicPlayerState[], viewerId: string): ResultsEntry[] {
  const total = players.length;

  return [...players]
    .map((player, index) => {
      const place = player.finishingPosition ?? index + 1;

      return {
        playerId: player.id,
        name: player.name,
        avatarColor: player.avatarColor,
        place,
        role: roleForPlace(place, total),
        points: scoreForPlace(place),
        isViewer: player.id === viewerId
      };
    })
    .sort(compareResults);
}

export function buildResultsData(state: PublicGameState): MatchResultsData {
  const entries = buildEntriesFromPlayers(state.players, state.viewerPlayerId);

  return {
    mode: "finished",
    title: "The Hierarchy",
    subtitle: "Session Results",
    entries,
    shifts: buildShifts(entries),
    actionLabel: "Continue to Exchange",
    footerText: "Match complete"
  };
}

export function buildMockResultsData(baseState?: PublicGameState | null): MatchResultsData {
  const fallbackPlayers: PublicPlayerState[] = [
    { id: "bot-1", name: "Marcus Vane", kind: "bot", avatarColor: "#FFD700", handCount: 0, status: "finished", finishingPosition: 1, isCurrentTurn: false },
    { id: "bot-2", name: "Elena Rossi", kind: "bot", avatarColor: "#C0C0C0", handCount: 0, status: "finished", finishingPosition: 2, isCurrentTurn: false },
    { id: "human-1", name: "Julian Exec", kind: "human", avatarColor: "#3b82f6", handCount: 0, status: "finished", finishingPosition: 3, isCurrentTurn: false },
    { id: "bot-3", name: "Jordan Smith", kind: "bot", avatarColor: "#CD7F32", handCount: 0, status: "finished", finishingPosition: 4, isCurrentTurn: false },
    { id: "bot-4", name: "Alex Chen", kind: "bot", avatarColor: "#ffb4ab", handCount: 0, status: "finished", finishingPosition: 5, isCurrentTurn: false }
  ];
  const sourcePlayers =
    baseState?.players.length && baseState.players.length >= 3
      ? baseState.players.map((player, index) => ({
          ...player,
          status: "finished" as const,
          finishingPosition: index + 1,
          isCurrentTurn: false
        }))
      : fallbackPlayers;
  const viewerId = baseState?.viewerPlayerId ?? "human-1";
  const nonViewerPlayers = sourcePlayers.filter((player) => player.id !== viewerId);
  const viewerPlayer = sourcePlayers.find((player) => player.id === viewerId);
  const orderedPlayers = [
    nonViewerPlayers[0],
    nonViewerPlayers[1],
    viewerPlayer,
    ...nonViewerPlayers.slice(2)
  ].filter((player): player is PublicPlayerState => Boolean(player));
  const placedPlayers = orderedPlayers.map((player, index) => ({
    ...player,
    finishingPosition: index + 1
  }));
  const entries = buildEntriesFromPlayers(placedPlayers, viewerId);

  return {
    mode: "mock",
    title: "The Hierarchy",
    subtitle: "Session Results",
    entries,
    shifts: buildShifts(entries),
    actionLabel: "Continue to Exchange",
    footerText: ""
  };
}

export class ResultsOverlay {
  private readonly root: HTMLDivElement;
  private readonly panel: HTMLDivElement;

  public constructor(parent: HTMLElement, private readonly onPrimaryAction: (mode: ResultsMode) => void) {
    this.ensureStyles();
    parent.style.position = "relative";

    this.root = document.createElement("div");
    this.root.className = "results-overlay";
    this.root.hidden = true;
    this.root.style.display = "none";

    this.panel = document.createElement("div");
    this.panel.className = "results-overlay__panel";
    this.root.appendChild(this.panel);
    parent.appendChild(this.root);
  }

  public show(data: MatchResultsData): void {
    this.panel.innerHTML = "";
    this.panel.append(
      this.buildHeader(data),
      this.buildEntries(data.entries),
      this.buildShifts(data.shifts),
      this.buildFooter(data)
    );
    this.root.hidden = false;
    this.root.style.display = "";
  }

  public hide(): void {
    this.root.hidden = true;
    this.root.style.display = "none";
  }

  private buildHeader(data: MatchResultsData): HTMLElement {
    const section = document.createElement("section");
    section.className = "results-overlay__header";
    section.innerHTML = `
      <div class="results-overlay__eyebrow">${data.subtitle}</div>
      <h2 class="results-overlay__title">${data.title}</h2>
      <div class="results-overlay__divider"></div>
    `;
    return section;
  }

  private buildEntries(entries: ResultsEntry[]): HTMLElement {
    const list = document.createElement("div");
    list.className = "results-overlay__list";

    entries.forEach((entry) => {
      const item = document.createElement("article");
      const roleClass = entry.place === 1 ? "is-primary" : entry.place === entries.length ? "is-danger" : entry.place === 2 ? "is-secondary" : "is-neutral";
      item.className = `results-entry ${entry.isViewer ? "is-viewer" : ""} ${roleClass}`;
      item.innerHTML = `
        <div class="results-entry__rank">${String(entry.place).padStart(2, "0")}</div>
        <div class="results-entry__avatar" style="--avatar:${entry.avatarColor}">
          <span>${initialFromName(entry.name)}</span>
        </div>
        <div class="results-entry__body">
          <div class="results-entry__name-row">
            <h4 class="results-entry__name">${entry.name}</h4>
            ${entry.isViewer ? `<span class="results-entry__you">YOU</span>` : ""}
          </div>
          <span class="results-entry__role">${entry.role}</span>
        </div>
        <div class="results-entry__score">
          <div class="results-entry__points">${entry.points.toLocaleString()}</div>
          <div class="results-entry__points-label">Points</div>
        </div>
      `;
      list.appendChild(item);
    });

    enableDragScroll(list, "y");

    return list;
  }

  private buildShifts(shifts: PowerShift[]): HTMLElement {
    const section = document.createElement("section");
    section.className = "results-overlay__shift";
    section.innerHTML = `
      <div class="results-overlay__shift-head">
        <div class="results-overlay__shift-title">The Power Shift</div>
        <div class="results-overlay__shift-icon">↔</div>
      </div>
    `;

    const grid = document.createElement("div");
    grid.className = "results-overlay__shift-grid";
    shifts.forEach((shift) => {
      const item = document.createElement("div");
      item.className = "results-overlay__shift-item";
      item.innerHTML = `
        <div class="results-overlay__shift-avatars">
          <div class="results-overlay__shift-avatar" style="--avatar:${shift.leftAvatarColor}">${shift.leftInitials}</div>
          <div class="results-overlay__shift-avatar" style="--avatar:${shift.rightAvatarColor}">${shift.rightInitials}</div>
        </div>
        <div class="results-overlay__shift-label">${shift.leftRole} <span>↔</span> ${shift.rightRole}</div>
        <div class="results-overlay__shift-meta">${shift.cardsLabel}</div>
      `;
      grid.appendChild(item);
    });
    enableDragScroll(grid, "x");
    section.appendChild(grid);
    return section;
  }

  private buildFooter(data: MatchResultsData): HTMLElement {
    const footer = document.createElement("section");
    footer.className = "results-overlay__footer";
    const button = document.createElement("button");
    button.className = "results-overlay__button";
    button.innerHTML = `${data.actionLabel}<span aria-hidden="true">›</span>`;
    button.addEventListener("click", () => this.onPrimaryAction(data.mode));

    const note = document.createElement("p");
    note.className = "results-overlay__note";
    note.textContent = data.footerText;

    footer.append(button, note);
    return footer;
  }

  private ensureStyles(): void {
    if (document.getElementById("results-overlay-styles")) {
      return;
    }

    const style = document.createElement("style");
    style.id = "results-overlay-styles";
    style.textContent = `
      .results-overlay {
        position: absolute;
        inset: 0;
        z-index: 30;
        overflow-y: auto;
        padding: 24px 16px 32px;
        background:
          linear-gradient(rgba(12,14,16,.92), rgba(12,14,16,.96)),
          radial-gradient(circle at top, rgba(255,215,0,.08), transparent 36%);
        backdrop-filter: blur(8px);
      }
      .results-overlay__panel {
        max-width: 440px;
        margin: 0 auto;
        color: ${palette.text};
        font-family: "Manrope", sans-serif;
      }
      .results-overlay__header {
        margin-bottom: 24px;
        text-align: center;
      }
      .results-overlay__eyebrow {
        display: inline-block;
        margin-bottom: 12px;
        padding: 6px 12px;
        border-radius: 999px;
        border: 1px solid rgba(255,215,0,.2);
        background: rgba(255,215,0,.08);
        color: ${palette.primary};
        font: 800 10px/1 "Space Grotesk", sans-serif;
        letter-spacing: .2em;
        text-transform: uppercase;
      }
      .results-overlay__title {
        margin: 0;
        font: 700 38px/1 "Space Grotesk", sans-serif;
        letter-spacing: -.04em;
      }
      .results-overlay__divider {
        width: 64px;
        height: 2px;
        margin: 14px auto 0;
        border-radius: 999px;
        background: linear-gradient(135deg, ${palette.primary} 0%, ${palette.primaryDim} 100%);
      }
      .results-overlay__list {
        display: grid;
        gap: 12px;
        margin-bottom: 24px;
      }
      .results-entry {
        display: grid;
        grid-template-columns: 32px 52px minmax(0, 1fr) auto;
        align-items: center;
        gap: 14px;
        padding: 16px;
        border-radius: 16px;
        background: rgba(40,42,44,.92);
        border-left: 4px solid rgba(143,145,148,.24);
        box-shadow: 0 14px 24px rgba(0,0,0,.2);
      }
      .results-entry.is-primary { border-left-color: ${palette.primary}; }
      .results-entry.is-secondary { border-left-color: rgba(198,198,198,.6); }
      .results-entry.is-danger { border-left-color: rgba(255,180,171,.65); opacity: .72; }
      .results-entry.is-neutral { border-left-color: rgba(205,127,50,.45); }
      .results-entry.is-viewer {
        border: 2px solid rgba(255,215,0,.22);
        box-shadow: inset 0 0 0 1px rgba(255,215,0,.08), 0 14px 28px rgba(0,0,0,.28);
      }
      .results-entry__rank {
        color: rgba(226,226,229,.18);
        font: 900 28px/1 "Space Grotesk", sans-serif;
        font-style: italic;
      }
      .results-entry__avatar {
        display: grid;
        place-items: center;
        width: 52px;
        height: 52px;
        border-radius: 999px;
        background: color-mix(in srgb, var(--avatar) 82%, #121416);
        border: 2px solid rgba(255,255,255,.1);
        font: 800 14px/1 "Space Grotesk", sans-serif;
        color: #121416;
      }
      .results-entry__body {
        min-width: 0;
      }
      .results-entry__name-row {
        display: flex;
        align-items: center;
        gap: 8px;
        min-width: 0;
      }
      .results-entry__name {
        margin: 0;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        font: 700 17px/1.1 "Space Grotesk", sans-serif;
      }
      .results-entry__you {
        padding: 3px 7px;
        border-radius: 999px;
        background: ${palette.primary};
        color: ${palette.onPrimary};
        font: 900 8px/1 "Manrope", sans-serif;
        letter-spacing: .12em;
      }
      .results-entry__role {
        display: inline-block;
        margin-top: 7px;
        padding: 4px 8px;
        border-radius: 999px;
        background: rgba(255,255,255,.06);
        color: ${palette.mutedText};
        font: 900 9px/1 "Manrope", sans-serif;
        letter-spacing: .14em;
        text-transform: uppercase;
      }
      .results-entry__score {
        text-align: right;
      }
      .results-entry__points {
        font: 700 20px/1 "Space Grotesk", sans-serif;
        color: ${palette.primary};
      }
      .results-entry__points-label {
        margin-top: 4px;
        color: ${palette.mutedText};
        font: 800 8px/1 "Manrope", sans-serif;
        letter-spacing: .12em;
        text-transform: uppercase;
      }
      .results-overlay__shift {
        margin-bottom: 24px;
        padding: 20px 18px 18px;
        border-radius: 22px;
        border: 1px solid rgba(255,255,255,.05);
        background: rgba(30,32,34,.7);
        box-shadow: inset 0 0 0 1px rgba(255,255,255,.02);
      }
      .results-overlay__shift-head {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 16px;
      }
      .results-overlay__shift-title {
        color: ${palette.mutedText};
        font: 900 10px/1 "Space Grotesk", sans-serif;
        letter-spacing: .2em;
        text-transform: uppercase;
      }
      .results-overlay__shift-icon {
        color: ${palette.primary};
        font: 900 16px/1 "Space Grotesk", sans-serif;
      }
      .results-overlay__shift-grid {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 14px;
      }
      .results-overlay__shift-item {
        padding: 14px 12px 12px;
        border-radius: 16px;
        border: 1px solid rgba(255,255,255,.05);
        background: rgba(51,53,55,.38);
        text-align: center;
      }
      .results-overlay__shift-avatars {
        display: flex;
        justify-content: center;
        margin-bottom: 12px;
      }
      .results-overlay__shift-avatar {
        display: grid;
        place-items: center;
        width: 32px;
        height: 32px;
        border-radius: 999px;
        margin-left: -8px;
        background: color-mix(in srgb, var(--avatar) 82%, #121416);
        border: 2px solid rgba(18,20,22,.9);
        box-shadow: 0 0 0 1px rgba(255,255,255,.12);
        color: #121416;
        font: 900 9px/1 "Space Grotesk", sans-serif;
      }
      .results-overlay__shift-avatar:first-child {
        margin-left: 0;
      }
      .results-overlay__shift-label {
        font: 900 10px/1.2 "Manrope", sans-serif;
        letter-spacing: .12em;
        text-transform: uppercase;
        color: ${palette.text};
      }
      .results-overlay__shift-label span {
        color: ${palette.primary};
      }
      .results-overlay__shift-meta {
        margin-top: 6px;
        color: ${palette.mutedText};
        font: 800 10px/1 "Manrope", sans-serif;
      }
      .results-overlay__footer {
        display: grid;
        gap: 14px;
      }
      .results-overlay__button {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 10px;
        width: 100%;
        padding: 18px 20px;
        border: 0;
        border-radius: 16px;
        cursor: pointer;
        background: linear-gradient(135deg, ${palette.primary} 0%, ${palette.primaryDim} 100%);
        color: ${palette.onPrimary};
        font: 900 12px/1 "Space Grotesk", sans-serif;
        letter-spacing: .18em;
        text-transform: uppercase;
        box-shadow: 0 16px 32px rgba(0,0,0,.28);
      }
      .results-overlay__button span {
        font-size: 24px;
        font-weight: 400;
        line-height: 1;
        transform: translateY(-1px);
      }
      .results-overlay__note {
        margin: 0;
        text-align: center;
        color: ${palette.mutedText};
        font: 800 10px/1 "Manrope", sans-serif;
        letter-spacing: .14em;
        text-transform: uppercase;
      }
    `;
    document.head.appendChild(style);
  }
}
