import Phaser from "phaser";
import type { Card, PublicGameState, PublicPlayerState } from "@president/shared";
import { GameApi } from "../../api/GameApi";
import { installDebugHooks } from "../debugHooks";
import { computeTableLayout, type TableLayout } from "../layout";
import { CardView } from "../objects/CardView";
import { palette, toColorNumber } from "../theme";

function hashString(value: string): number {
  let hash = 0;

  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) >>> 0;
  }

  return hash;
}

function buildAngleSequence(count: number, seed: string): number[] {
  const baseAngles = [-10, -8, -6, -4, -2, 0, 2, 4, 6, 8, 10];
  const values: number[] = [];
  let remaining = [...baseAngles];
  let cursor = hashString(seed);

  while (values.length < count) {
    if (remaining.length === 0) {
      remaining = [...baseAngles];
    }

    const index = cursor % remaining.length;
    values.push(remaining.splice(index, 1)[0]);
    cursor = (cursor * 1103515245 + 12345) >>> 0;
  }

  return values;
}

interface SeatWidgets {
  container: Phaser.GameObjects.Container;
  ring: Phaser.GameObjects.Arc;
  halo: Phaser.GameObjects.Arc;
  badgeBg: Phaser.GameObjects.Rectangle;
  badgeText: Phaser.GameObjects.Text;
  nameText: Phaser.GameObjects.Text;
  countBg: Phaser.GameObjects.Arc;
  countIcon: Phaser.GameObjects.Text;
  cardCountText: Phaser.GameObjects.Text;
  statusText: Phaser.GameObjects.Text;
}

export class GameScene extends Phaser.Scene {
  private readonly debugMode = import.meta.env.DEV;
  private readonly api = new GameApi();
  private gameState: PublicGameState | null = null;
  private readonly selectedCardIds = new Set<string>();
  private seatWidgets = new Map<string, SeatWidgets>();
  private handCards: CardView[] = [];
  private displayedPileCards: Array<{ card: Card; key: string }> = [];
  private lastSeenPileTimestamp: number | null = null;
  private centerGroup?: Phaser.GameObjects.Container;
  private backdrop?: Phaser.GameObjects.Graphics;
  private chromeGraphics?: Phaser.GameObjects.Graphics;
  private requirementText?: Phaser.GameObjects.Text;
  private statusBanner?: Phaser.GameObjects.Container;
  private actionButton?: Phaser.GameObjects.Container;
  private logText?: Phaser.GameObjects.Text;
  private debugToggle?: Phaser.GameObjects.Container;
  private debugLogVisible = false;
  private botTimer?: Phaser.Time.TimerEvent;
  private busy = false;

  public constructor() {
    super("game");
  }

  public async create(): Promise<void> {
    this.cameras.main.setBackgroundColor(palette.background);
    this.backdrop = this.add.graphics();
    this.chromeGraphics = this.add.graphics();

    installDebugHooks(() => this.gameState, () => this.renderState());

    this.scale.on("resize", () => this.renderState());
    this.input.on("pointerup", (pointer: Phaser.Input.Pointer) => {
      if (this.tryTriggerButton(this.actionButton, pointer.x, pointer.y) || this.tryTriggerButton(this.debugToggle, pointer.x, pointer.y)) {
        return;
      }

      const clickedCard = [...this.handCards]
        .sort((left, right) => right.depth - left.depth)
        .find((card) => card.containsScreenPoint(pointer.x, pointer.y));

      if (clickedCard) {
        this.toggleCardSelection(clickedCard.card);
      }
    });
    if (this.debugMode) {
      this.input.keyboard?.on("keydown-BACKTICK", () => {
        this.debugLogVisible = !this.debugLogVisible;
        this.renderState();
      });
    }

    await this.loadNewGame();
  }

  private async loadNewGame(): Promise<void> {
    this.busy = true;
    this.gameState = await this.api.createGame();
    this.selectedCardIds.clear();
    this.displayedPileCards = [];
    this.lastSeenPileTimestamp = null;
    this.busy = false;
    this.renderState();
    this.scheduleBotTurnIfNeeded();
  }

  private async submitAction(
    payload: { type: "play"; playerId: string; cardIds: string[] } | { type: "pass"; playerId: string }
  ): Promise<void> {
    if (this.busy) {
      return;
    }

    this.busy = true;
    try {
      this.gameState = await this.api.submitAction(payload);
      this.selectedCardIds.clear();
      this.scheduleBotTurnIfNeeded();
    } catch (error) {
      this.showBanner(error instanceof Error ? error.message : "Action failed");
    } finally {
      this.busy = false;
      this.renderState();
    }
  }

  private toggleCardSelection(card: Card): void {
    const state = this.gameState;
    if (!state || state.phase !== "playing" || state.currentTurnPlayerId !== state.viewerPlayerId) {
      return;
    }

    if (!state.viewerHand.some((viewerCard) => viewerCard.id === card.id)) {
      return;
    }

    if (this.selectedCardIds.has(card.id)) {
      this.selectedCardIds.delete(card.id);
    } else {
      this.selectedCardIds.add(card.id);
    }

    this.renderHand();
  }

  private getSelectableCardIds(state: PublicGameState): Set<string> {
    const playerCanAct = state.phase === "playing" && state.currentTurnPlayerId === state.viewerPlayerId && !this.busy;
    if (!playerCanAct) {
      return new Set<string>();
    }

    if (this.selectedCardIds.size === 0) {
      return new Set(state.viewerHand.map((card) => card.id));
    }

    const selectedCards = state.viewerHand.filter((card) => this.selectedCardIds.has(card.id));
    if (selectedCards.length === 0) {
      return new Set(state.viewerHand.map((card) => card.id));
    }

    const selectedRank = selectedCards[0].rank;
    const currentSet = state.pile.currentSet;
    const maxCount = currentSet?.count ?? 4;
    const selectionComplete = this.selectedCardIds.size >= maxCount;
    const selectable = new Set<string>(selectedCards.map((card) => card.id));

    if (selectionComplete) {
      return selectable;
    }

    if (currentSet && selectedRank <= currentSet.rank) {
      return selectable;
    }

    state.viewerHand.forEach((card) => {
      if (!this.selectedCardIds.has(card.id) && card.rank === selectedRank) {
        selectable.add(card.id);
      }
    });

    return selectable;
  }

  private createButton(label: string, primary: boolean, onTap: () => void): Phaser.GameObjects.Container {
    const button = this.add.container(0, 0);
    const width = primary ? 172 : 132;
    const height = 48;
    const glow = this.add
      .ellipse(0, 6, width + 22, height + 18, toColorNumber(palette.primary), primary ? 0.22 : 0)
      .setVisible(primary);
    const background = this.add.graphics();
    const text = this.add
      .text(0, 0, label, {
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: "16px",
        color: primary ? palette.surfaceLowest : palette.text,
        fontStyle: "bold"
      })
      .setOrigin(0.5);

    button.add([glow, background, text]);
    button.setSize(width, height);
    button.setInteractive(
      new Phaser.Geom.Rectangle(-width / 2, -height / 2, width, height),
      Phaser.Geom.Rectangle.Contains
    );
    button.setData("background", background);
    button.setData("glow", glow);
    button.setData("label", text);
    button.setData("primary", primary);
    button.setData("buttonWidth", width);
    button.setData("buttonHeight", height);
    button.setData("enabled", true);
    button.setData("onTap", onTap);
    button.on("pointerup", onTap);
    this.redrawButton(button, true);
    return button;
  }

  private ensureChrome(): void {
    if (!this.requirementText) {
      this.requirementText = this.add
        .text(0, 0, "", {
          fontFamily: "Manrope, sans-serif",
          fontSize: "15px",
          color: palette.text,
          backgroundColor: palette.surfaceHigh,
          padding: { x: 12, y: 7 }
        })
        .setOrigin(0.5);
    }

    if (!this.statusBanner) {
      const background = this.add.graphics();
      const label = this.add
        .text(0, 0, "", {
          fontFamily: "Manrope, sans-serif",
          fontSize: "14px",
          color: palette.text,
          fontStyle: "bold",
          align: "center"
        })
        .setOrigin(0.5);
      this.statusBanner = this.add.container(0, 0, [background, label]);
      this.statusBanner.setData("background", background);
      this.statusBanner.setData("label", label);
    }

    if (!this.logText) {
      this.logText = this.add
        .text(0, 0, "", {
          fontFamily: "Manrope, sans-serif",
          fontSize: "13px",
          color: palette.mutedText,
          align: "center",
          wordWrap: { width: 360 }
        })
        .setOrigin(0.5);
    }

    if (this.debugMode && !this.debugToggle) {
      this.debugToggle = this.createButton("Debug Log", false, () => {
        this.debugLogVisible = !this.debugLogVisible;
        this.renderState();
      });
      this.add.existing(this.debugToggle);
    }

    if (!this.actionButton) {
      this.actionButton = this.createButton("Pass", true, async () => {
        const state = this.gameState;
        if (!state) {
          return;
        }

        if (this.selectedCardIds.size === 0) {
          await this.submitAction({
            type: "pass",
            playerId: state.viewerPlayerId
          });
          return;
        }

        await this.submitAction({
          type: "play",
          playerId: state.viewerPlayerId,
          cardIds: [...this.selectedCardIds]
        });
      });
      this.add.existing(this.actionButton);
    }
  }

  private updateButtonState(button: Phaser.GameObjects.Container | undefined, enabled: boolean, labelText?: string): void {
    if (!button) {
      return;
    }

    const label = button.getData("label") as Phaser.GameObjects.Text;

    if (labelText) {
      label.setText(labelText);
    }

    button.setData("enabled", enabled);
    label.setAlpha(enabled ? 1 : 0.7);
    button.setAlpha(enabled ? 1 : 0.75);
    button.disableInteractive();
    if (enabled) {
      button.setInteractive(
        new Phaser.Geom.Rectangle(-button.width / 2, -button.height / 2, button.width, button.height),
        Phaser.Geom.Rectangle.Contains
      );
    }

    this.redrawButton(button, enabled);
  }

  private redrawButton(button: Phaser.GameObjects.Container, enabled: boolean): void {
    const background = button.getData("background") as Phaser.GameObjects.Graphics;
    const glow = button.getData("glow") as Phaser.GameObjects.Ellipse | undefined;
    const primary = button.getData("primary") as boolean;
    const width = button.getData("buttonWidth") as number;
    const height = button.getData("buttonHeight") as number;
    const radius = height / 2;

    background.clear();

    if (glow) {
      glow.setVisible(primary);
      glow.setAlpha(primary ? (enabled ? 0.28 : 0.16) : 0);
    }

    if (primary) {
      background.fillStyle(toColorNumber(palette.primary), enabled ? 1 : 0.78);
      background.fillRoundedRect(-width / 2, -height / 2, width, height, radius);
    } else {
      background.fillStyle(toColorNumber(palette.surfaceHigh), enabled ? 0.95 : 0.72);
      background.fillRoundedRect(-width / 2, -height / 2, width, height, radius);
      background.lineStyle(1.25, toColorNumber(palette.outlineVariant), 0.4);
      background.strokeRoundedRect(-width / 2, -height / 2, width, height, radius);
    }
  }

  private refreshActionButton(layout: TableLayout, state: PublicGameState): void {
    if (!this.actionButton) {
      return;
    }

    const canAct = state.phase === "playing" && state.currentTurnPlayerId === state.viewerPlayerId && !this.busy;
    const isPassing = this.selectedCardIds.size === 0;
    this.actionButton.setPosition(this.scale.width / 2, layout.actionBarY);
    this.actionButton.setDepth(200);
    this.updateButtonState(
      this.actionButton,
      canAct,
      isPassing ? "Pass" : "Play Hand"
    );
  }

  private tryTriggerButton(button: Phaser.GameObjects.Container | undefined, x: number, y: number): boolean {
    if (!button || !button.visible || button.alpha <= 0.01 || button.getData("enabled") !== true) {
      return false;
    }

    if (!button.getBounds().contains(x, y)) {
      return false;
    }

    const onTap = button.getData("onTap") as (() => void) | undefined;
    onTap?.();
    return true;
  }

  private scheduleBotTurnIfNeeded(): void {
    this.botTimer?.remove(false);
    this.botTimer = undefined;

    const state = this.gameState;
    if (!state || state.phase !== "playing") {
      return;
    }

    const currentPlayer = state.players.find((player) => player.id === state.currentTurnPlayerId);
    if (!currentPlayer || currentPlayer.kind !== "bot") {
      return;
    }

    this.updateStatusBanner(`${currentPlayer.name} is thinking`);
    this.botTimer = this.time.delayedCall(850, async () => {
      try {
        this.gameState = await this.api.stepBotTurn();
        this.renderState();
        this.scheduleBotTurnIfNeeded();
      } catch (error) {
        this.showBanner(error instanceof Error ? error.message : "Bot turn failed");
      }
    });
  }

  private setDebugVisibility(layout: TableLayout): void {
    if (!this.logText) {
      return;
    }

    if (!this.debugMode) {
      this.logText.setVisible(false);
      this.debugToggle?.setVisible(false);
      return;
    }

    this.debugToggle?.setVisible(true);
    this.debugToggle?.setPosition(layout.tableFrame.x + 74, layout.requirementY);
    this.updateButtonState(this.debugToggle, true);

    const visible = this.debugLogVisible;
    this.logText
      .setVisible(visible)
      .setAlpha(visible ? 1 : 0)
      .setPosition(layout.logBox.x, layout.logBox.y)
      .setWordWrapWidth(layout.logBox.width - 28, true);
  }

  private drawBackdrop(layout: TableLayout): void {
    if (!this.backdrop || !this.chromeGraphics) {
      return;
    }

    const { width, height } = this.scale;
    const table = layout.tableFrame;

    this.backdrop.clear();
    this.backdrop.fillGradientStyle(
      toColorNumber(palette.surfaceLowest),
      toColorNumber(palette.surface),
      toColorNumber(palette.surfaceLowest),
      toColorNumber(palette.surfaceLow),
      1
    );
    this.backdrop.fillRect(0, 0, width, height);

    this.chromeGraphics.clear();

    if (this.debugMode && this.debugLogVisible) {
      this.chromeGraphics.fillStyle(toColorNumber(palette.surfaceHigh), 0.9);
      this.chromeGraphics.fillRoundedRect(
        layout.logBox.x - layout.logBox.width / 2,
        layout.logBox.y - layout.logBox.height / 2,
        layout.logBox.width,
        layout.logBox.height,
        18
      );
      this.chromeGraphics.lineStyle(1.2, toColorNumber(palette.outlineVariant), 0.32);
      this.chromeGraphics.strokeRoundedRect(
        layout.logBox.x - layout.logBox.width / 2,
        layout.logBox.y - layout.logBox.height / 2,
        layout.logBox.width,
        layout.logBox.height,
        18
      );
    }
  }

  private renderState(): void {
    const state = this.gameState;
    if (!state) {
      return;
    }

    this.syncDisplayedPile(state);

    const { width } = this.scale;
    const layout = computeTableLayout(this.scale.width, this.scale.height, state);
    this.drawBackdrop(layout);
    this.ensureChrome();

    this.requirementText?.setVisible(false);

    const currentPlayer = state.players.find((player) => player.id === state.currentTurnPlayerId);
    const statusText =
      state.phase === "finished"
        ? "Round Finished"
        : currentPlayer?.kind === "bot"
          ? `${currentPlayer.name} is thinking`
          : "";
    this.updateStatusBanner(statusText, width / 2, layout.statusY);

    this.renderPlayers(layout, state);
    this.renderCenter(layout, state);
    this.renderHand();

    this.refreshActionButton(layout, state);

    const logLines = state.log.slice(-3).map((entry) => entry.text).join("\n");
    this.logText
      ?.setText(logLines)
      .setPosition(layout.logBox.x, layout.logBox.y);
    this.setDebugVisibility(layout);
  }

  private syncDisplayedPile(state: PublicGameState): void {
    const currentSet = state.pile.currentSet;

    if (!currentSet) {
      this.displayedPileCards = [];
      this.lastSeenPileTimestamp = null;
      return;
    }

    if (this.lastSeenPileTimestamp === currentSet.timestamp) {
      return;
    }

    if (this.lastSeenPileTimestamp === null) {
      this.displayedPileCards = [];
    }

    const pileKeyPrefix = `${currentSet.timestamp}`;
    currentSet.cards.forEach((card, index) => {
      this.displayedPileCards.push({
        card,
        key: `${pileKeyPrefix}-${index}-${card.id}`
      });
    });
    this.displayedPileCards = this.displayedPileCards.slice(-12);
    this.lastSeenPileTimestamp = currentSet.timestamp;
  }

  private renderPlayers(layout: TableLayout, state: PublicGameState): void {
    const activeIds = new Set(state.players.map((player) => player.id));
    let topSeatIndex = 0;

    for (const [playerId, widgets] of this.seatWidgets.entries()) {
      if (!activeIds.has(playerId)) {
        widgets.container.destroy(true);
        this.seatWidgets.delete(playerId);
      }
    }

    state.players.forEach((player) => {
      const isViewer = player.id === state.viewerPlayerId;
      const seat = isViewer ? layout.viewerSeat : layout.topSeats[topSeatIndex++];
      let widgets = this.seatWidgets.get(player.id);

      if (!widgets) {
        const ring = this.add.circle(0, 0, 34).setStrokeStyle(2, toColorNumber(palette.outline), 0.35);
        const halo = this.add.circle(0, 0, 27, Number.parseInt(player.avatarColor.replace("#", ""), 16), 1);
        const badgeBg = this.add.rectangle(0, -52, 82, 18, toColorNumber(palette.surfaceHigh)).setAlpha(0.95);
        const badgeText = this.add
          .text(0, -52, "", {
            fontFamily: "Manrope, sans-serif",
            fontSize: "10px",
            color: palette.text,
            fontStyle: "bold"
          })
          .setOrigin(0.5);
        const nameText = this.add
          .text(0, 48, player.name, {
            fontFamily: "Space Grotesk, sans-serif",
            fontSize: "13px",
            color: palette.text,
            fontStyle: "bold"
          })
          .setOrigin(0.5);
        const countBg = this.add.circle(24, -20, 13, toColorNumber(palette.surfaceHigh)).setAlpha(0.98);
        const countIcon = this.add
          .text(24, -15, "♢", {
            fontFamily: "Space Grotesk, sans-serif",
            fontSize: "8px",
            color: palette.mutedText,
            fontStyle: "bold"
          })
          .setOrigin(0.5);
        const cardCountText = this.add
          .text(24, -24, "", {
            fontFamily: "Manrope, sans-serif",
            fontSize: "10px",
            color: palette.text
          })
          .setOrigin(0.5);
        const statusText = this.add
          .text(0, 86, "", {
            fontFamily: "Manrope, sans-serif",
            fontSize: "11px",
            color: palette.mutedText
          })
          .setOrigin(0.5);
        const container = this.add.container(seat.x, seat.y, [
          badgeBg,
          badgeText,
          ring,
          halo,
          nameText,
          countBg,
          countIcon,
          cardCountText,
          statusText
        ]);
        widgets = { container, ring, halo, badgeBg, badgeText, nameText, countBg, countIcon, cardCountText, statusText };
        this.seatWidgets.set(player.id, widgets);
      }

      if (!widgets) {
        return;
      }

      const badge = this.describeSeatBadge(player, state.players.length);
      widgets.container.setPosition(seat.x, seat.y);
      widgets.nameText.setText(player.name);
      widgets.cardCountText.setText(String(player.handCount));
      const status = this.describeStatus(player, false);
      widgets.statusText.setText(status);
      widgets.statusText.setVisible(status.length > 0);
      widgets.badgeText.setText(badge.text);
      widgets.badgeBg.setFillStyle(toColorNumber(badge.fill), badge.alpha);
      widgets.badgeText.setColor(badge.color);
      widgets.countBg.setStrokeStyle(1, toColorNumber(palette.outlineVariant), 0.32);
      widgets.countIcon.setColor(palette.mutedText);
      widgets.cardCountText.setColor(badge.countColor ?? badge.color);
      widgets.halo.setAlpha(player.status === "finished" ? 0.55 : 1);
      widgets.halo.setScale(player.isCurrentTurn ? 1.08 : 1);
      widgets.ring.setStrokeStyle(2.5, toColorNumber(badge.ring), player.isCurrentTurn ? 1 : 0.55);
      widgets.ring.setScale(player.isCurrentTurn ? 1.12 : 1);
      this.animateSeatState(widgets, isViewer ? 1 : layout.topSeatScale, player.isCurrentTurn, player.status === "finished");
      widgets.container.setDepth(player.isCurrentTurn ? 220 : isViewer ? 210 : 20);
    });
  }

  private animateSeatState(
    widgets: SeatWidgets,
    baseScale: number,
    isCurrentTurn: boolean,
    isFinished: boolean
  ): void {
    const targetScale = isCurrentTurn ? baseScale * 1.14 : baseScale * (isFinished ? 0.82 : 0.9);
    const targetAlpha = isCurrentTurn ? 1 : isFinished ? 0.38 : 0.58;
    const previousScale = widgets.container.getData("targetScale") as number | undefined;
    const previousAlpha = widgets.container.getData("targetAlpha") as number | undefined;

    if (previousScale === targetScale && previousAlpha === targetAlpha) {
      return;
    }

    widgets.container.setData("targetScale", targetScale);
    widgets.container.setData("targetAlpha", targetAlpha);
    this.tweens.killTweensOf(widgets.container);
    this.tweens.add({
      targets: widgets.container,
      scaleX: targetScale,
      scaleY: targetScale,
      alpha: targetAlpha,
      duration: 220,
      ease: "Quad.Out"
    });
  }

  private renderCenter(layout: TableLayout, state: PublicGameState): void {
    this.centerGroup?.destroy(true);

    const children: Phaser.GameObjects.GameObject[] = [];
    const glow = this.add.circle(layout.center.x, layout.center.y, layout.centerPanelWidth * 0.42, toColorNumber(palette.primary), 0.08);
    children.push(glow);

    if (this.displayedPileCards.length > 0) {
      const visibleCards = this.displayedPileCards;
      const angleSteps = buildAngleSequence(Math.max(0, visibleCards.length - 1), visibleCards.map((entry) => entry.key).join("|"));
      let runningAngle = 0;
      let stackBand = 0;

      visibleCards.forEach((entry, index) => {
        const { card } = entry;
        if (index > 0) {
          const nextStep = angleSteps[index - 1];
          if (runningAngle + nextStep > 90) {
            runningAngle = 0;
            stackBand += 1;
          } else {
            runningAngle += nextStep;
          }
        }

        const signedAngle = (stackBand % 2 === 0 ? 1 : -1) * runningAngle;
        const bandOffsetX = stackBand * 10;
        const bandOffsetY = stackBand * 6;
        const radius = Math.min(18, 6 + index * 0.7);
        const radians = Phaser.Math.DegToRad(signedAngle);
        const cardX = layout.center.x + Math.cos(radians) * radius + bandOffsetX;
        const cardY = layout.center.y + Math.sin(radians) * radius * 0.65 + bandOffsetY;
        const cardView = new CardView(this, card, cardX, cardY + 2);
        cardView.setScale(1.08);
        cardView.setAngle(signedAngle);
        cardView.setSelected(false);
        cardView.setAvailabilityState(true, false);
        cardView.setDepth(40 + index * 2);
        children.push(cardView);
      });
    } else {
      const emptyText = this.add
        .text(layout.center.x, layout.center.y - 4, "New Round", {
          fontFamily: "Space Grotesk, sans-serif",
          fontSize: "28px",
          color: palette.primary,
          fontStyle: "bold"
        })
        .setOrigin(0.5);
      const helperText = this.add
        .text(layout.center.x, layout.center.y + 34, "Play any valid set to lead.", {
          fontFamily: "Manrope, sans-serif",
          fontSize: "13px",
          color: palette.mutedText
        })
        .setOrigin(0.5);
      children.push(emptyText, helperText);
    }

    this.centerGroup = this.add.container(0, 0, children);
  }

  private renderHand(): void {
    const state = this.gameState;
    if (!state) {
      return;
    }

    this.handCards.forEach((card) => card.destroy());
    this.handCards = [];

    const { width, height } = this.scale;
    const layout = computeTableLayout(width, height, state);
    const fanSize = state.viewerHand.length;
    const spread = fanSize > 1 ? Math.min(layout.handSpread, (layout.trayWidth - 120) / (fanSize - 1)) : 0;
    const startX = width / 2 - (spread * Math.max(0, fanSize - 1)) / 2;
    const baseScale = layout.isTablet ? 1.06 : 0.96;
    const sharedHitWidth = fanSize <= 1 ? 72 : Math.max(24, Math.min(46, spread + 8));
    const selectableCardIds = this.getSelectableCardIds(state);

    state.viewerHand.forEach((card, index) => {
      const selected = this.selectedCardIds.has(card.id);
      const selectable = selectableCardIds.has(card.id);
      const normalized = fanSize > 1 ? index / (fanSize - 1) - 0.5 : 0;
      const angle = normalized * 34;
      const curveLift = Math.abs(normalized) * 18;
      const y = layout.handY + curveLift - (selected ? 20 : 0);
      const cardView = new CardView(this, card, startX + spread * index, y);
      cardView.setScale(baseScale);
      cardView.setAngle(angle);
      cardView.setDepth(100 + index + (selected ? 1000 : 0));
      cardView.setHitAreaProfile(
        selected ? 72 : index === 0 || index === fanSize - 1 ? Math.max(sharedHitWidth, 40) : sharedHitWidth,
        Phaser.Math.Clamp(Math.sin(Phaser.Math.DegToRad(angle)) * 16, -16, 16)
      );
      cardView.setSelected(selected);
      cardView.setAvailabilityState(selectable, selected);
      this.handCards.push(cardView);
    });

    this.refreshActionButton(layout, state);
  }

  private describeSeatBadge(
    player: PublicPlayerState,
    playerCount: number
  ): { text: string; fill: string; color: string; ring: string; alpha: number; countColor?: string } {
    if (player.finishingPosition === 1) {
      return { text: "President", fill: palette.primary, color: palette.onPrimary, ring: palette.primary, alpha: 1, countColor: palette.primary };
    }

    if (player.finishingPosition === 2) {
      return { text: "Vice", fill: palette.surfaceHigh, color: palette.secondary, ring: palette.secondary, alpha: 1, countColor: palette.secondary };
    }

    if (player.finishingPosition === playerCount) {
      return { text: "Scum", fill: palette.dangerDim, color: palette.danger, ring: palette.danger, alpha: 0.95, countColor: palette.danger };
    }

    if (player.status === "finished") {
      return { text: `#${player.finishingPosition ?? "-"}`, fill: palette.surfaceHigh, color: palette.secondary, ring: palette.secondary, alpha: 0.95, countColor: palette.secondary };
    }

    if (player.status === "passed") {
      return { text: "Citizen", fill: palette.surfaceHigh, color: palette.text, ring: palette.outline, alpha: 0.92 };
    }

    if (player.isCurrentTurn) {
      return { text: "Citizen", fill: palette.surfaceHigh, color: palette.text, ring: palette.primary, alpha: 0.98, countColor: palette.primary };
    }

    return { text: "Citizen", fill: palette.surfaceHigh, color: palette.text, ring: palette.outlineVariant, alpha: 0.92 };
  }

  private describeStatus(player: PublicGameState["players"][number] | undefined, isViewer: boolean): string {
    if (!player) {
      return "";
    }

    if (player.status === "finished") {
      return player.finishingPosition ? `Finished #${player.finishingPosition}` : "Finished";
    }

    if (player.isCurrentTurn) {
      return "";
    }

    if (player.status === "passed") {
      return "";
    }

    return "";
  }

  private showBanner(message: string): void {
    this.updateStatusBanner(message);
    this.time.delayedCall(1800, () => this.renderState());
  }

  private updateStatusBanner(message: string, x?: number, y?: number): void {
    if (!this.statusBanner) {
      return;
    }

    const label = this.statusBanner.getData("label") as Phaser.GameObjects.Text;
    const background = this.statusBanner.getData("background") as Phaser.GameObjects.Graphics;
    label.setText(message);
    this.statusBanner.setVisible(message.length > 0);

    if (x !== undefined && y !== undefined) {
      this.statusBanner.setPosition(x, y);
    }

    background.clear();
    if (message.length === 0) {
      return;
    }

    const paddingX = 16;
    const paddingY = 10;
    const width = label.width + paddingX * 2;
    const height = label.height + paddingY * 2;
    background.fillStyle(toColorNumber(palette.surfaceHigh), 0.96);
    background.lineStyle(1.25, toColorNumber(palette.outlineVariant), 0.42);
    background.fillRoundedRect(-width / 2, -height / 2, width, height, height / 2);
    background.strokeRoundedRect(-width / 2, -height / 2, width, height, height / 2);
  }
}
