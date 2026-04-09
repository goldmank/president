import type { Card, PublicGameState, PublicPlayerState, Suit } from "@president/shared";
import { compareCards, createDeck, rankLabelMap } from "@president/shared";
import { palette } from "../game/theme";
import { enableDragScroll } from "./dragScroll";

type ExchangeMode = "preview" | "mock";

interface ExchangeSeat {
  playerId: string;
  name: string;
  role: string;
  avatarColor: string;
  isViewer: boolean;
}

interface ExchangeHandCard {
  card: Card;
  rankLabel: string;
  suitSymbol: string;
  suitClass: string;
}

export interface ExchangeOverlayData {
  mode: ExchangeMode;
  title: string;
  subtitle: string;
  requiredCount: number;
  viewerRole: string;
  viewerName: string;
  instruction: string;
  primaryLabel: string;
  secondaryLabel: string;
  counterpartSeats: ExchangeSeat[];
  hand: ExchangeHandCard[];
}

function roleForPlace(place: number, total: number): string {
  if (place === 1) {
    return "President";
  }

  if (place === 2) {
    return "Vice";
  }

  if (place === total) {
    return "Scum";
  }

  if (place === total - 1 && total >= 4) {
    return "Vice Scum";
  }

  return "Citizen";
}

function suitSymbol(suit: Suit): string {
  switch (suit) {
    case "hearts":
      return "♥";
    case "diamonds":
      return "♦";
    case "clubs":
      return "♣";
    case "spades":
      return "♠";
    case "joker":
      return "★";
  }
}

function suitClass(suit: Suit): string {
  if (suit === "joker") {
    return "is-gold";
  }

  return suit === "hearts" || suit === "diamonds" ? "is-red" : "is-dark";
}

function handCards(cards: Card[]): ExchangeHandCard[] {
  return [...cards].sort(compareCards).map((card) => ({
    card,
    rankLabel: rankLabelMap[card.rank],
    suitSymbol: suitSymbol(card.suit),
    suitClass: suitClass(card.suit)
  }));
}

function requirementForRole(role: string): { count: number; instruction: string } {
  switch (role) {
    case "President":
      return { count: 2, instruction: "Select your 2 worst assets to send to the Scum" };
    case "Vice":
      return { count: 1, instruction: "Select your weakest card to send to the Vice Scum" };
    case "Scum":
      return { count: 2, instruction: "Select your 2 best assets to send to the President" };
    case "Vice Scum":
      return { count: 1, instruction: "Select your best card to send to the Vice" };
    default:
      return { count: 0, instruction: "No exchange required. Wait for the hierarchy to finish trading" };
  }
}

function deriveSeats(players: PublicPlayerState[], viewerId: string): ExchangeSeat[] {
  const total = players.length;

  return [...players]
    .map((player, index) => ({
      playerId: player.id,
      name: player.name,
      role: roleForPlace(player.finishingPosition ?? index + 1, total),
      avatarColor: player.avatarColor,
      isViewer: player.id === viewerId
    }))
    .sort((left, right) => {
      const leftPlace = players.find((player) => player.id === left.playerId)?.finishingPosition ?? 99;
      const rightPlace = players.find((player) => player.id === right.playerId)?.finishingPosition ?? 99;
      return leftPlace - rightPlace;
    });
}

function deriveCounterpartSeats(seats: ExchangeSeat[], viewerRole: string, viewerId: string): ExchangeSeat[] {
  const viewerSeat = seats.find((seat) => seat.playerId === viewerId);
  if (!viewerSeat) {
    return [];
  }

  const roleTargets: Record<string, string[]> = {
    President: ["Scum"],
    "Vice": ["Vice Scum"],
    Scum: ["President"],
    "Vice Scum": ["Vice"]
  };

  const targets = roleTargets[viewerRole] ?? [];
  const counterpart = seats.find((seat) => targets.includes(seat.role));
  return counterpart ? [viewerSeat, counterpart] : [viewerSeat];
}

function fallbackHand(): Card[] {
  return createDeck().filter((card) => ["3-clubs", "3-diamonds", "5-spades", "6-hearts", "7-clubs", "8-diamonds", "9-spades", "10-clubs", "11-hearts", "12-diamonds", "13-spades", "14-hearts", "15-clubs"].includes(card.id));
}

export function buildExchangePreviewData(state: PublicGameState): ExchangeOverlayData {
  const seats = deriveSeats(state.players, state.viewerPlayerId);
  const viewerSeat = seats.find((seat) => seat.isViewer) ?? seats[0];
  const { count, instruction } = requirementForRole(viewerSeat?.role ?? "Citizen");

  return {
    mode: "preview",
    title: "POWER SHIFT",
    subtitle: instruction,
    requiredCount: count,
    viewerRole: viewerSeat?.role ?? "Citizen",
    viewerName: viewerSeat?.name ?? "You",
    instruction,
    primaryLabel: count > 0 ? "Confirm Exchange" : "Continue to Match",
    secondaryLabel: count > 0 ? "Leave Game" : "Close",
    counterpartSeats: deriveCounterpartSeats(seats, viewerSeat?.role ?? "Citizen", state.viewerPlayerId),
    hand: handCards(state.viewerHand.length > 0 ? state.viewerHand : fallbackHand())
  };
}

export function buildMockExchangeData(baseState?: PublicGameState | null): ExchangeOverlayData {
  const viewerId = baseState?.viewerPlayerId ?? "human-1";
  const players: PublicPlayerState[] =
    baseState?.players.length && baseState.players.length >= 4
      ? baseState.players.map((player, index) => ({
          ...player,
          finishingPosition: player.id === viewerId ? 1 : index === 0 ? 5 : index === 1 ? 2 : index + 1,
          status: "finished",
          isCurrentTurn: false
        }))
      : [
          { id: "bot-1", name: "Marcus Vane", kind: "bot", avatarColor: "#C39A1C", handCount: 0, status: "finished", finishingPosition: 1, isCurrentTurn: false },
          { id: "bot-2", name: "Elena Rossi", kind: "bot", avatarColor: "#C0C0C0", handCount: 0, status: "finished", finishingPosition: 2, isCurrentTurn: false },
          { id: "human-1", name: "Julian Exec", kind: "human", avatarColor: "#3b82f6", handCount: 13, status: "finished", finishingPosition: 1, isCurrentTurn: false },
          { id: "bot-3", name: "Jordan Smith", kind: "bot", avatarColor: "#CD7F32", handCount: 0, status: "finished", finishingPosition: 4, isCurrentTurn: false },
          { id: "bot-4", name: "Alex Chen", kind: "bot", avatarColor: "#ffb4ab", handCount: 0, status: "finished", finishingPosition: 5, isCurrentTurn: false }
        ];

  const orderedPlayers = players.map((player) => {
    if (player.id === viewerId) {
      return { ...player, finishingPosition: 1 };
    }
    return player;
  });
  const mockState: PublicGameState = {
    id: "mock-exchange",
    phase: "playing",
    rules: baseState?.rules ?? { minPlayers: 3, maxPlayers: 8, clearOnTwo: false },
    players: orderedPlayers,
    viewerPlayerId: viewerId,
    viewerHand: baseState?.viewerHand.length ? baseState.viewerHand : fallbackHand(),
    currentTurnPlayerId: viewerId,
    lastSuccessfulPlayerId: null,
    pile: { currentSet: null, history: [] },
    requirementText: "New Round",
    log: []
  };

    return {
    ...buildExchangePreviewData(mockState),
    mode: "mock",
    primaryLabel: "Confirm Exchange",
    secondaryLabel: "Leave Game"
  };
}

export class ExchangeOverlay {
  private readonly root: HTMLDivElement;
  private readonly panel: HTMLDivElement;
  private currentData: ExchangeOverlayData | null = null;
  private readonly selectedIds = new Set<string>();
  private handScrollLeft = 0;

  public constructor(
    parent: HTMLElement,
    private readonly onConfirm: (mode: ExchangeMode, selectedCardIds: string[]) => void,
    private readonly onCancel: (mode: ExchangeMode) => void
  ) {
    this.ensureStyles();
    parent.style.position = "relative";

    this.root = document.createElement("div");
    this.root.className = "exchange-overlay";
    this.root.hidden = true;
    this.root.style.position = "absolute";
    this.root.style.inset = "0";
    this.root.style.zIndex = "35";
    this.root.style.display = "none";
    this.root.style.placeItems = "center";
    this.root.style.padding = "16px";
    this.root.style.background = "rgba(12, 14, 16, 0.62)";
    this.root.style.backdropFilter = "blur(6px)";

    this.panel = document.createElement("div");
    this.panel.className = "exchange-overlay__panel";
    this.panel.style.width = "min(100%, 420px)";
    this.panel.style.minHeight = "620px";
    this.panel.style.maxHeight = "min(760px, calc(100vh - 32px))";
    this.panel.style.display = "flex";
    this.panel.style.flexDirection = "column";
    this.panel.style.overflow = "auto";
    this.panel.style.position = "relative";
    this.panel.style.borderTop = `2px solid ${palette.primary}`;
    this.panel.style.borderRadius = "16px";
    this.panel.style.background = palette.surfaceContainer;
    this.panel.style.boxShadow = "0 32px 64px rgba(0,0,0,.8)";
    this.panel.style.color = palette.text;
    this.panel.style.fontFamily = '"Manrope", sans-serif';
    this.root.appendChild(this.panel);
    parent.appendChild(this.root);
  }

  public show(data: ExchangeOverlayData): void {
    this.currentData = data;
    this.selectedIds.clear();
    this.handScrollLeft = 0;
    this.panel.scrollTop = 0;
    this.render();
    this.root.hidden = false;
    this.root.style.display = "grid";
  }

  public hide(): void {
    this.currentData = null;
    this.selectedIds.clear();
    this.handScrollLeft = 0;
    this.root.hidden = true;
    this.root.style.display = "none";
  }

  private render(): void {
    if (!this.currentData) {
      this.panel.innerHTML = "";
      return;
    }

    const data = this.currentData;
    this.panel.innerHTML = "";

    try {
      this.panel.append(
        this.buildHeader(data),
        this.buildDropZone(data),
        this.buildHand(data),
        this.buildFooter(data)
      );
    } catch (error) {
      console.error("Failed to render exchange overlay", error);
      this.panel.innerHTML = `
        <section class="exchange-overlay__fallback">
          <h2>${data.title}</h2>
          <p>${data.subtitle}</p>
          <p>Required cards: ${data.requiredCount}</p>
          <p>Viewer role: ${data.viewerRole}</p>
          <p>Hand size: ${data.hand.length}</p>
        </section>
      `;
    }
  }

  private buildHeader(data: ExchangeOverlayData): HTMLElement {
    const header = document.createElement("section");
    header.className = "exchange-overlay__header";
    header.style.flex = "0 0 auto";
    header.style.padding = "28px 24px 16px";
    header.style.textAlign = "center";

    const seats = document.createElement("div");
    seats.className = "exchange-overlay__seats";
    seats.style.display = "flex";
    seats.style.justifyContent = "center";
    seats.style.gap = "14px";
    seats.style.marginTop = "18px";
    seats.style.flexWrap = "wrap";
    data.counterpartSeats.forEach((seat) => {
      const seatEl = document.createElement("div");
      seatEl.className = `exchange-overlay__seat ${seat.isViewer ? "is-viewer" : ""}`;
      seatEl.style.display = "grid";
      seatEl.style.gap = "10px";
      seatEl.style.justifyItems = "center";
      if (seat.isViewer) {
        seatEl.style.transform = "scale(1.06)";
      }
      seatEl.innerHTML = `
        <div class="exchange-overlay__seat-avatar-wrap">
          <div class="exchange-overlay__seat-avatar" style="--avatar:${seat.avatarColor}">${seat.name.slice(0, 1).toUpperCase()}</div>
        </div>
        <div class="exchange-overlay__seat-role">${seat.role.toUpperCase()}</div>
        <div class="exchange-overlay__seat-name">${seat.name}</div>
      `;
      seats.appendChild(seatEl);
    });

    header.innerHTML = `
      <h2 class="exchange-overlay__title">${data.title}</h2>
      <p class="exchange-overlay__subtitle">${data.subtitle}</p>
    `;
    header.appendChild(seats);
    const title = header.querySelector(".exchange-overlay__title") as HTMLElement | null;
    const subtitle = header.querySelector(".exchange-overlay__subtitle") as HTMLElement | null;
    if (title) {
      title.style.margin = "0 0 10px";
      title.style.color = palette.primary;
      title.style.font = '900 34px/1 "Space Grotesk", sans-serif';
      title.style.letterSpacing = "-0.04em";
      title.style.textTransform = "uppercase";
    }
    if (subtitle) {
      subtitle.style.margin = "0";
      subtitle.style.color = palette.mutedText;
      subtitle.style.font = '500 14px/1.5 "Manrope", sans-serif';
    }
    seats.querySelectorAll(".exchange-overlay__seat-avatar").forEach((element) => {
      const avatar = element as HTMLElement;
      avatar.style.display = "grid";
      avatar.style.placeItems = "center";
      avatar.style.width = "58px";
      avatar.style.height = "58px";
      avatar.style.borderRadius = "999px";
      avatar.style.background = "color-mix(in srgb, var(--avatar) 82%, #121416)";
      avatar.style.border = "2px solid rgba(255,255,255,.12)";
      avatar.style.color = "#121416";
      avatar.style.font = '800 16px/1 "Space Grotesk", sans-serif';
      avatar.style.boxShadow = "0 10px 20px rgba(0,0,0,.24)";
    });
    seats.querySelectorAll(".exchange-overlay__seat-avatar-wrap").forEach((element) => {
      const wrap = element as HTMLElement;
      wrap.style.position = "relative";
      wrap.style.display = "grid";
      wrap.style.placeItems = "center";
    });
    seats.querySelectorAll(".exchange-overlay__seat-role").forEach((element) => {
      const role = element as HTMLElement;
      role.style.order = "-1";
      role.style.padding = "4px 9px";
      role.style.borderRadius = "999px";
      role.style.background = "rgba(255,255,255,.08)";
      role.style.font = '800 10px/1 "Manrope", sans-serif';
      role.style.letterSpacing = ".12em";
      role.style.textTransform = "uppercase";
      role.style.color = palette.text;
    });
    seats.querySelectorAll(".exchange-overlay__seat-name").forEach((element) => {
      const name = element as HTMLElement;
      name.style.font = '700 13px/1.1 "Space Grotesk", sans-serif';
      name.style.color = palette.text;
      name.style.textAlign = "center";
    });
    return header;
  }

  private buildDropZone(data: ExchangeOverlayData): HTMLElement {
    const section = document.createElement("section");
    section.className = "exchange-overlay__slots";
    section.style.flex = "0 0 auto";
    section.style.display = "flex";
    section.style.justifyContent = "center";
    section.style.gap = "20px";
    section.style.padding = "22px 24px";
    section.style.background = "rgba(26,28,30,.5)";

    if (data.requiredCount === 0) {
      section.innerHTML = `<div class="exchange-overlay__waiting">No cards to trade from your side.</div>`;
      const waiting = section.firstElementChild as HTMLElement | null;
      if (waiting) {
        waiting.style.color = palette.mutedText;
        waiting.style.font = '700 13px/1.4 "Manrope", sans-serif';
      }
      return section;
    }

    for (let index = 0; index < data.requiredCount; index += 1) {
      const cardId = [...this.selectedIds][index];
      const card = data.hand.find((entry) => entry.card.id === cardId);
      const slot = document.createElement("div");
      slot.className = `exchange-slot ${card ? "is-filled" : ""} ${card?.suitClass ?? ""}`;
      slot.style.width = "88px";
      slot.style.minHeight = "132px";
      slot.style.borderRadius = "14px";
      slot.style.border = `2px ${card ? "solid" : "dashed"} ${card ? palette.primary : palette.outlineVariant}`;
      slot.style.background = card ? palette.surfaceHighest : "rgba(12,14,16,.5)";
      slot.style.display = "grid";
      slot.style.placeItems = "center";
      slot.style.position = "relative";
      slot.style.padding = "12px";
      slot.style.boxShadow = card ? "0 12px 20px rgba(0,0,0,.24)" : "";
      slot.style.color = card?.suitClass === "is-red" ? palette.danger : palette.text;
      slot.style.cursor = card ? "pointer" : "default";
      slot.innerHTML = card
        ? `
          <div class="exchange-card__rank">${card.rankLabel}</div>
          <div class="exchange-card__suit">${card.suitSymbol}</div>
          <div class="exchange-card__rank exchange-card__rank--bottom">${card.rankLabel}</div>
        `
        : `
          <div class="exchange-slot__plus">+</div>
          <div class="exchange-slot__label">Slot ${index + 1}</div>
        `;
      if (card) {
        slot.addEventListener("click", () => {
          this.selectedIds.delete(card.card.id);
          this.render();
        });
      }
      section.appendChild(slot);
    }

    section.querySelectorAll(".exchange-card__rank").forEach((element) => {
      const rank = element as HTMLElement;
      rank.style.position = "absolute";
      rank.style.top = "8px";
      rank.style.left = "10px";
      rank.style.font = '700 18px/1 "Space Grotesk", sans-serif';
    });
    section.querySelectorAll(".exchange-card__rank--bottom").forEach((element) => {
      const rank = element as HTMLElement;
      rank.style.top = "auto";
      rank.style.right = "10px";
      rank.style.bottom = "8px";
      rank.style.left = "auto";
      rank.style.transform = "rotate(180deg)";
    });
    section.querySelectorAll(".exchange-card__suit").forEach((element) => {
      const suit = element as HTMLElement;
      suit.style.position = "absolute";
      suit.style.inset = "0";
      suit.style.display = "grid";
      suit.style.placeItems = "center";
      suit.style.font = '700 30px/1 "Space Grotesk", sans-serif';
    });
    section.querySelectorAll(".exchange-slot__label").forEach((element) => {
      const label = element as HTMLElement;
      label.style.position = "absolute";
      label.style.bottom = "10px";
      label.style.left = "0";
      label.style.right = "0";
      label.style.textAlign = "center";
      label.style.color = palette.outline;
      label.style.font = '800 10px/1 "Manrope", sans-serif';
      label.style.letterSpacing = ".14em";
      label.style.textTransform = "uppercase";
    });
    section.querySelectorAll(".exchange-slot__plus").forEach((element) => {
      const plus = element as HTMLElement;
      plus.style.color = palette.outline;
      plus.style.font = '300 34px/1 "Manrope", sans-serif';
    });

    return section;
  }

  private buildHand(data: ExchangeOverlayData): HTMLElement {
    const section = document.createElement("section");
    section.className = "exchange-overlay__hand";
    section.style.flex = "1 1 auto";
    section.style.padding = "22px 0 18px";
    section.innerHTML = `
      <div class="exchange-overlay__hand-head">
        <h3>Your Assets</h3>
        <span>${data.hand.length} Cards</span>
      </div>
    `;
    const head = section.querySelector(".exchange-overlay__hand-head") as HTMLElement | null;
    if (head) {
      head.style.display = "flex";
      head.style.justifyContent = "space-between";
      head.style.alignItems = "center";
      head.style.padding = "0 24px 14px";
    }
    head?.querySelectorAll("h3, span").forEach((element) => {
      const el = element as HTMLElement;
      el.style.margin = "0";
      el.style.font = '800 11px/1 "Manrope", sans-serif';
      el.style.letterSpacing = ".14em";
      el.style.textTransform = "uppercase";
      if (el.tagName === "SPAN") {
        el.style.color = palette.mutedText;
      }
    });

    const rail = document.createElement("div");
    rail.className = "exchange-overlay__hand-rail";
    rail.style.display = "flex";
    rail.style.gap = "12px";
    rail.style.overflowX = "auto";
    rail.style.padding = "0 24px 6px";
    data.hand.filter((entry) => !this.selectedIds.has(entry.card.id)).forEach((entry) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `exchange-hand-card ${entry.suitClass}`;
      button.style.position = "relative";
      button.style.width = "68px";
      button.style.height = "98px";
      button.style.flex = "0 0 auto";
      button.style.borderRadius = "10px";
      button.style.border = `1px solid ${palette.outlineVariant}`;
      button.style.background = palette.surfaceHighest;
      button.style.color = entry.suitClass === "is-red" ? palette.danger : palette.text;
      button.style.cursor = "pointer";
      button.innerHTML = `
        <div class="exchange-card__rank">${entry.rankLabel}</div>
        <div class="exchange-card__suit">${entry.suitSymbol}</div>
        <div class="exchange-card__rank exchange-card__rank--bottom">${entry.rankLabel}</div>
      `;
      button.addEventListener("click", () => {
        this.handScrollLeft = rail.scrollLeft;
        if (this.selectedIds.size < data.requiredCount) {
          this.selectedIds.add(entry.card.id);
        }
        this.render();
      });
      rail.appendChild(button);
    });
    enableDragScroll(rail, "x");
    rail.addEventListener("scroll", () => {
      this.handScrollLeft = rail.scrollLeft;
    });
    section.appendChild(rail);
    requestAnimationFrame(() => {
      rail.scrollLeft = this.handScrollLeft;
    });
    section.querySelectorAll(".exchange-card__rank").forEach((element) => {
      const rank = element as HTMLElement;
      rank.style.position = "absolute";
      rank.style.top = "8px";
      rank.style.left = "10px";
      rank.style.font = '700 18px/1 "Space Grotesk", sans-serif';
    });
    section.querySelectorAll(".exchange-card__rank--bottom").forEach((element) => {
      const rank = element as HTMLElement;
      rank.style.top = "auto";
      rank.style.right = "10px";
      rank.style.bottom = "8px";
      rank.style.left = "auto";
      rank.style.transform = "rotate(180deg)";
    });
    section.querySelectorAll(".exchange-card__suit").forEach((element) => {
      const suit = element as HTMLElement;
      suit.style.position = "absolute";
      suit.style.inset = "0";
      suit.style.display = "grid";
      suit.style.placeItems = "center";
      suit.style.font = '700 30px/1 "Space Grotesk", sans-serif';
    });
    return section;
  }

  private buildFooter(data: ExchangeOverlayData): HTMLElement {
    const footer = document.createElement("section");
    footer.className = "exchange-overlay__footer";
    footer.style.flex = "0 0 auto";
    footer.style.padding = "0 24px 24px";
    const confirm = document.createElement("button");
    confirm.className = "exchange-overlay__confirm";
    confirm.type = "button";
    confirm.disabled = this.selectedIds.size !== data.requiredCount;
    confirm.innerHTML = `${data.primaryLabel}<span aria-hidden="true">↔</span>`;
    confirm.style.display = "flex";
    confirm.style.alignItems = "center";
    confirm.style.justifyContent = "center";
    confirm.style.gap = "10px";
    confirm.style.width = "100%";
    confirm.style.height = "60px";
    confirm.style.border = "0";
    confirm.style.borderRadius = "999px";
    confirm.style.background = `linear-gradient(135deg, ${palette.primary} 0%, ${palette.primaryDim} 100%)`;
    confirm.style.color = palette.onPrimary;
    confirm.style.cursor = confirm.disabled ? "default" : "pointer";
    confirm.style.font = '900 14px/1 "Space Grotesk", sans-serif';
    confirm.style.letterSpacing = ".18em";
    confirm.style.textTransform = "uppercase";
    confirm.style.opacity = confirm.disabled ? "0.45" : "1";
    confirm.addEventListener("click", () => this.onConfirm(data.mode, [...this.selectedIds]));

    const cancel = document.createElement("button");
    cancel.className = "exchange-overlay__cancel";
    cancel.type = "button";
    cancel.textContent = data.secondaryLabel;
    cancel.style.width = "100%";
    cancel.style.marginTop = "22px";
    cancel.style.border = "0";
    cancel.style.background = "transparent";
    cancel.style.color = palette.outline;
    cancel.style.font = '800 11px/1 "Manrope", sans-serif';
    cancel.style.letterSpacing = ".14em";
    cancel.style.textTransform = "uppercase";
    cancel.style.cursor = "pointer";
    cancel.addEventListener("click", () => this.onCancel(data.mode));

    footer.append(confirm, cancel);
    return footer;
  }

  private ensureStyles(): void {
    if (document.getElementById("exchange-overlay-styles")) {
      return;
    }

    const style = document.createElement("style");
    style.id = "exchange-overlay-styles";
    style.textContent = `
      .exchange-overlay {
        position: absolute;
        inset: 0;
        z-index: 35;
        display: grid;
        place-items: center;
        padding: 16px;
        background: rgba(12, 14, 16, 0.62);
        backdrop-filter: blur(6px);
      }
      .exchange-overlay__panel {
        width: min(100%, 420px);
        min-height: 620px;
        max-height: min(760px, calc(100vh - 32px));
        display: flex;
        flex-direction: column;
        overflow: auto;
        position: relative;
        border-top: 2px solid ${palette.primary};
        border-radius: 16px;
        background: ${palette.surfaceContainer};
        box-shadow: 0 32px 64px rgba(0,0,0,.8);
        color: ${palette.text};
        font-family: "Manrope", sans-serif;
      }
      .exchange-overlay__header {
        flex: 0 0 auto;
        padding: 28px 24px 16px;
        text-align: center;
      }
      .exchange-overlay__title {
        margin: 0 0 10px;
        color: ${palette.primary};
        font: 900 28px/1.05 "Space Grotesk", sans-serif;
        letter-spacing: -.04em;
        text-transform: uppercase;
      }
      .exchange-overlay__subtitle {
        margin: 0;
        color: ${palette.mutedText};
        font: 500 14px/1.5 "Manrope", sans-serif;
      }
      .exchange-overlay__seats {
        display: flex;
        justify-content: center;
        gap: 14px;
        margin-top: 18px;
        flex-wrap: wrap;
      }
      .exchange-overlay__seat {
        display: grid;
        gap: 8px;
        justify-items: center;
      }
      .exchange-overlay__seat.is-viewer {
        transform: scale(1.06);
      }
      .exchange-overlay__seat-avatar {
        display: grid;
        place-items: center;
        width: 52px;
        height: 52px;
        border-radius: 14px;
        background: color-mix(in srgb, var(--avatar) 82%, #121416);
        border: 1px solid rgba(255,255,255,.12);
        color: #121416;
        font: 800 14px/1 "Space Grotesk", sans-serif;
      }
      .exchange-overlay__seat.is-viewer .exchange-overlay__seat-avatar {
        border: 2px solid ${palette.primary};
        box-shadow: 0 10px 20px rgba(0,0,0,.3);
      }
      .exchange-overlay__seat-role {
        padding: 4px 8px;
        border-radius: 4px;
        background: rgba(255,255,255,.08);
        font: 800 10px/1 "Manrope", sans-serif;
        letter-spacing: .12em;
        text-transform: uppercase;
      }
      .exchange-overlay__seat.is-viewer .exchange-overlay__seat-role {
        background: ${palette.primary};
        color: ${palette.onPrimary};
      }
      .exchange-overlay__slots {
        flex: 0 0 auto;
        display: flex;
        justify-content: center;
        gap: 20px;
        padding: 22px 24px;
        background: rgba(26,28,30,.5);
      }
      .exchange-slot {
        width: 88px;
        min-height: 132px;
        border-radius: 14px;
        border: 2px dashed ${palette.outlineVariant};
        background: rgba(12,14,16,.5);
        display: grid;
        place-items: center;
        position: relative;
        padding: 12px;
      }
      .exchange-slot.is-filled,
      .exchange-hand-card.is-selected {
        border-style: solid;
        border-color: ${palette.primary};
        background: ${palette.surfaceHighest};
        box-shadow: 0 12px 20px rgba(0,0,0,.24);
      }
      .exchange-slot__plus {
        color: ${palette.outline};
        font: 300 34px/1 "Manrope", sans-serif;
      }
      .exchange-slot__label {
        position: absolute;
        bottom: 10px;
        left: 0;
        right: 0;
        text-align: center;
        color: ${palette.outline};
        font: 800 10px/1 "Manrope", sans-serif;
        letter-spacing: .14em;
        text-transform: uppercase;
      }
      .exchange-overlay__waiting {
        color: ${palette.mutedText};
        font: 700 13px/1.4 "Manrope", sans-serif;
      }
      .exchange-overlay__hand {
        flex: 1 1 auto;
        padding: 22px 0 18px;
      }
      .exchange-overlay__hand-head {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0 24px 14px;
      }
      .exchange-overlay__hand-head h3,
      .exchange-overlay__hand-head span {
        margin: 0;
        font: 800 11px/1 "Manrope", sans-serif;
        letter-spacing: .14em;
        text-transform: uppercase;
      }
      .exchange-overlay__hand-head span {
        color: ${palette.mutedText};
      }
      .exchange-overlay__hand-rail {
        display: flex;
        gap: 12px;
        overflow-x: auto;
        padding: 0 24px 6px;
      }
      .exchange-overlay__hand-rail::-webkit-scrollbar {
        height: 4px;
      }
      .exchange-overlay__hand-rail::-webkit-scrollbar-thumb {
        background: ${palette.primary};
        border-radius: 999px;
      }
      .exchange-hand-card {
        position: relative;
        width: 68px;
        height: 98px;
        flex: 0 0 auto;
        border-radius: 10px;
        border: 1px solid ${palette.outlineVariant};
        background: ${palette.surfaceHighest};
        cursor: pointer;
      }
      .exchange-card__rank {
        position: absolute;
        top: 8px;
        left: 10px;
        font: 700 18px/1 "Space Grotesk", sans-serif;
      }
      .exchange-card__rank--bottom {
        top: auto;
        right: 10px;
        bottom: 8px;
        left: auto;
        transform: rotate(180deg);
      }
      .exchange-card__suit {
        position: absolute;
        inset: 0;
        display: grid;
        place-items: center;
        font: 700 30px/1 "Space Grotesk", sans-serif;
      }
      .exchange-hand-card.is-red,
      .exchange-slot.is-red {
        color: ${palette.danger};
      }
      .exchange-hand-card.is-dark,
      .exchange-slot.is-dark {
        color: ${palette.text};
      }
      .exchange-hand-card.is-gold,
      .exchange-slot.is-gold {
        color: ${palette.primary};
      }
      .exchange-overlay__footer {
        flex: 0 0 auto;
        padding: 0 24px 24px;
      }
      .exchange-overlay__fallback {
        padding: 32px 24px;
      }
      .exchange-overlay__fallback h2 {
        margin: 0 0 12px;
        color: ${palette.primary};
        font: 900 24px/1.1 "Space Grotesk", sans-serif;
        text-transform: uppercase;
      }
      .exchange-overlay__fallback p {
        margin: 0 0 10px;
        color: ${palette.text};
        font: 600 14px/1.4 "Manrope", sans-serif;
      }
      .exchange-overlay__confirm {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 10px;
        width: 100%;
        height: 60px;
        border: 0;
        border-radius: 999px;
        background: linear-gradient(135deg, ${palette.primary} 0%, ${palette.primaryDim} 100%);
        color: ${palette.onPrimary};
        cursor: pointer;
        font: 900 12px/1 "Space Grotesk", sans-serif;
        letter-spacing: .18em;
        text-transform: uppercase;
      }
      .exchange-overlay__confirm:disabled {
        opacity: .45;
        cursor: default;
      }
      .exchange-overlay__cancel {
        width: 100%;
        margin-top: 14px;
        border: 0;
        background: transparent;
        color: ${palette.outline};
        font: 800 11px/1 "Manrope", sans-serif;
        letter-spacing: .14em;
        text-transform: uppercase;
        cursor: pointer;
      }
    `;
    document.head.appendChild(style);
  }
}
