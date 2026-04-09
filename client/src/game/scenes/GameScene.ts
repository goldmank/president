import Phaser from "phaser";
import type { Card, PublicGameState, PublicPlayerState } from "@president/shared";
import { GameApi } from "../../api/GameApi";
import { installDebugHooks } from "../debugHooks";
import { computeTableLayout, type TableLayout } from "../layout";
import { CardView } from "../objects/CardView";
import { buildMockResultsData, buildResultsData } from "../../results/resultsOverlay";
import { palette, toColorNumber } from "../theme";
import { applyTextResolution } from "../text";

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
  handFan: Phaser.GameObjects.Container;
  statusText: Phaser.GameObjects.Text;
}

interface PilePose {
  x: number;
  y: number;
  angle: number;
  depth: number;
}

interface HandBackPose {
  localX: number;
  localY: number;
  angle: number;
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
  private fadingDisplayedPile = false;
  private clearPileTimer?: Phaser.Time.TimerEvent;
  private centerGroup?: Phaser.GameObjects.Container;
  private backdrop?: Phaser.GameObjects.Graphics;
  private chromeGraphics?: Phaser.GameObjects.Graphics;
  private requirementText?: Phaser.GameObjects.Text;
  private statusBanner?: Phaser.GameObjects.Container;
  private actionButton?: Phaser.GameObjects.Container;
  private logText?: Phaser.GameObjects.Text;
  private debugHelpText?: Phaser.GameObjects.Text;
  private debugToggle?: Phaser.GameObjects.Container;
  private debugMenu?: Phaser.GameObjects.Container;
  private debugMenuVisible = false;
  private botTimer?: Phaser.Time.TimerEvent;
  private busy = false;
  private mockResultsEnabled = import.meta.env.DEV && new URLSearchParams(window.location.search).get("mockResults") === "1";
  private mockExchangeEnabled = import.meta.env.DEV && new URLSearchParams(window.location.search).get("mockExchange") === "1";

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
      const pointerX = pointer.x;
      const pointerY = pointer.y;

      if (this.tryTriggerButton(this.actionButton, pointerX, pointerY) || this.tryTriggerButton(this.debugToggle, pointerX, pointerY)) {
        return;
      }

      const clickedCard = [...this.handCards]
        .sort((left, right) => right.depth - left.depth)
        .find((card) => card.containsScreenPoint(pointerX, pointerY));

      if (clickedCard) {
        this.toggleCardSelection(clickedCard.card);
      }
    });
    if (this.debugMode) {
      window.toggleMockResults = (enabled?: boolean) => {
        this.mockResultsEnabled = enabled ?? !this.mockResultsEnabled;
        this.renderState();
      };
      window.toggleMockExchange = (enabled?: boolean) => {
        this.mockExchangeEnabled = enabled ?? !this.mockExchangeEnabled;
        this.renderState();
      };
      this.input.keyboard?.on("keydown-BACKTICK", () => {
        this.debugMenuVisible = !this.debugMenuVisible;
        this.renderState();
      });
      this.input.keyboard?.on("keydown-R", () => {
        this.mockResultsEnabled = !this.mockResultsEnabled;
        this.renderState();
      });
      this.input.keyboard?.on("keydown-X", () => {
        this.mockExchangeEnabled = !this.mockExchangeEnabled;
        this.renderState();
      });
      this.input.keyboard?.on("keydown-F", () => {
        void this.fastForwardGame();
      });
    }

    await this.loadNewGame();
  }

  public startNewGame(): void {
    void this.loadNewGame();
  }

  public setMockResultsEnabled(enabled: boolean): void {
    this.mockResultsEnabled = enabled;
    this.renderState();
  }

  public setMockExchangeEnabled(enabled: boolean): void {
    this.mockExchangeEnabled = enabled;
    this.renderState();
  }

  public getCurrentState(): PublicGameState | null {
    return this.gameState;
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
      if (payload.type === "play") {
        await this.animatePlayedCards(payload.cardIds);
      }

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

  private async fastForwardGame(): Promise<void> {
    if (!this.debugMode || this.busy) {
      return;
    }

    this.busy = true;
    this.botTimer?.remove(false);
    this.botTimer = undefined;

    try {
      this.gameState = await this.api.fastForwardGame();
    } catch (error) {
      this.showBanner(error instanceof Error ? error.message : "Fast forward failed");
    } finally {
      this.busy = false;
      this.renderState();
      this.scheduleBotTurnIfNeeded();
    }
  }

  private computePilePoses(layout: TableLayout, keys: string[]): PilePose[] {
    const angleSteps = buildAngleSequence(Math.max(0, keys.length - 1), keys.join("|"));
    const poses: PilePose[] = [];
    let runningAngle = 0;
    let stackBand = 0;

    keys.forEach((key, index) => {
      void key;

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

      poses.push({
        x: layout.center.x + Math.cos(radians) * radius + bandOffsetX,
        y: layout.center.y + Math.sin(radians) * radius * 0.65 + bandOffsetY + 2,
        angle: signedAngle,
        depth: 40 + index * 2
      });
    });

    return poses;
  }

  private getSeatForPlayer(layout: TableLayout, state: PublicGameState, playerId: string): { seat: { x: number; y: number }; isViewer: boolean } | null {
    let topSeatIndex = 0;

    for (const player of state.players) {
      const isViewer = player.id === state.viewerPlayerId;
      const seat = isViewer ? layout.viewerSeat : layout.topSeats[topSeatIndex++];
      if (player.id === playerId) {
        return { seat, isViewer };
      }
    }

    return null;
  }

  private getSeatVisualScale(layout: TableLayout, player: PublicPlayerState, isViewer: boolean): number {
    const baseScale = isViewer ? 1 : layout.topSeatScale;
    if (player.isCurrentTurn) {
      return baseScale * 1.14;
    }

    if (player.status === "finished") {
      return baseScale * 0.82;
    }

    return baseScale * 0.9;
  }

  private buildSeatHandBackPoses(seat: { x: number; y: number }, center: { x: number; y: number }, handCount: number): HandBackPose[] {
    const visibleCount = Math.max(0, Math.min(5, handCount));
    if (visibleCount === 0) {
      return [];
    }

    const dx = center.x - seat.x;
    const dy = center.y - seat.y;
    const distance = Math.max(Math.hypot(dx, dy), 1);
    const dirX = dx / distance;
    const dirY = dy / distance;
    const perpX = -dirY;
    const perpY = dirX;
    const anchorX = dirX * 54;
    const anchorY = dirY * 54;
    const baseAngle = Phaser.Math.RadToDeg(Math.atan2(dirY, dirX)) + 90;
    const spacing = visibleCount <= 1 ? 0 : 10;

    return Array.from({ length: visibleCount }, (_value, index) => {
      const normalized = visibleCount > 1 ? index / (visibleCount - 1) - 0.5 : 0;
      const spreadOffset = normalized * spacing * Math.max(1, visibleCount - 1);
      return {
        localX: anchorX + perpX * spreadOffset + dirX * Math.abs(normalized) * 3,
        localY: anchorY + perpY * spreadOffset + dirY * Math.abs(normalized) * 3,
        angle: baseAngle + normalized * 12
      };
    });
  }

  private createBackCard(localX: number, localY: number, angle: number): Phaser.GameObjects.Container {
    const shell = this.add.rectangle(0, 0, 30, 42, toColorNumber(palette.surfaceHigh)).setStrokeStyle(1.1, toColorNumber(palette.outline), 0.48);
    const inner = this.add.rectangle(0, 0, 24, 36, toColorNumber(palette.surfaceContainer)).setStrokeStyle(1, toColorNumber(palette.outlineVariant), 0.35);
    const band = this.add.rectangle(0, 0, 12, 26, toColorNumber(palette.primary), 0.22);
    const mark = applyTextResolution(this.add
      .text(0, 0, "♢", {
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: "10px",
        color: palette.primary,
        fontStyle: "bold"
      })
      .setOrigin(0.5)
      .setAlpha(0.65));

    return this.add.container(localX, localY, [shell, inner, band, mark]).setAngle(angle);
  }

  private async animatePlayedCards(cardIds: string[]): Promise<void> {
    const state = this.gameState;
    if (!state || cardIds.length === 0) {
      return;
    }

    const movingCards = this.handCards.filter((cardView) => cardIds.includes(cardView.card.id));
    if (movingCards.length === 0) {
      return;
    }

    const layout = computeTableLayout(this.scale.width, this.scale.height, state);
    const existingKeys = this.displayedPileCards.map((entry) => entry.key);
    const animationKeys = [...existingKeys, ...movingCards.map((cardView) => `anim-${cardView.card.id}`)];
    const targetPoses = this.computePilePoses(layout, animationKeys).slice(-movingCards.length);
    const overlayCards = movingCards.map((cardView, index) => {
      const clone = new CardView(this, cardView.card, cardView.x, cardView.y);
      clone.syncPose(cardView.x, cardView.y, cardView.angle, cardView.scaleX, 500 + index);
      clone.setHitAreaProfile(72, 0);
      clone.setSelected(true);
      clone.setAvailabilityState(true, true);
      return clone;
    });

    movingCards.forEach((cardView) => {
      cardView.setVisible(false);
    });

    await new Promise<void>((resolve) => {
      let completed = 0;

      overlayCards.forEach((cardView, index) => {
        const pose = targetPoses[index];
        this.tweens.add({
          targets: cardView,
          x: pose?.x ?? cardView.x,
          y: pose?.y ?? cardView.y,
          angle: pose?.angle ?? cardView.angle,
          scaleX: 1.02,
          scaleY: 1.02,
          duration: 340,
          delay: index * 55,
          ease: "Cubic.InOut",
          onStart: () => {
            cardView.setDepth((pose?.depth ?? 500) + index);
          },
          onComplete: () => {
            completed += 1;
            if (completed !== overlayCards.length) {
              return;
            }

            overlayCards.forEach((overlayCard) => overlayCard.destroy());
            movingCards.forEach((movingCard) => movingCard.setVisible(true));
            resolve();
          }
        });
      });
    });
  }

  private async animateSeatPlayedCards(previousState: PublicGameState, nextState: PublicGameState): Promise<void> {
    const currentSet = nextState.pile.currentSet;
    if (!currentSet || currentSet.byPlayerId === nextState.viewerPlayerId) {
      return;
    }

    const previousSetTimestamp = previousState.pile.currentSet?.timestamp ?? null;
    if (previousSetTimestamp === currentSet.timestamp) {
      return;
    }

    const player = previousState.players.find((entry) => entry.id === currentSet.byPlayerId);
    if (!player) {
      return;
    }

    const layout = computeTableLayout(this.scale.width, this.scale.height, previousState);
    const seatInfo = this.getSeatForPlayer(layout, previousState, currentSet.byPlayerId);
    if (!seatInfo) {
      return;
    }

    const seatScale = this.getSeatVisualScale(layout, player, seatInfo.isViewer);
    const sourcePoses = this.buildSeatHandBackPoses(seatInfo.seat, layout.center, player.handCount).slice(-currentSet.cards.length);
    if (sourcePoses.length === 0) {
      return;
    }

    const existingKeys = this.displayedPileCards.map((entry) => entry.key);
    const animationKeys = [...existingKeys, ...currentSet.cards.map((card) => `anim-${currentSet.timestamp}-${card.id}`)];
    const targetPoses = this.computePilePoses(layout, animationKeys).slice(-currentSet.cards.length);
    const overlayCards = currentSet.cards.map((card, index) => {
      const sourcePose = sourcePoses[Math.min(index, sourcePoses.length - 1)];
      const globalX = seatInfo.seat.x + sourcePose.localX * seatScale;
      const globalY = seatInfo.seat.y + sourcePose.localY * seatScale;
      const cardView = new CardView(this, card, globalX, globalY);
      cardView.syncPose(globalX, globalY, sourcePose.angle, 0.48 * seatScale, 500 + index);
      cardView.setAvailabilityState(true, false);
      return cardView;
    });

    await new Promise<void>((resolve) => {
      let completed = 0;

      overlayCards.forEach((cardView, index) => {
        const pose = targetPoses[index];
        this.tweens.add({
          targets: cardView,
          x: pose?.x ?? cardView.x,
          y: pose?.y ?? cardView.y,
          angle: pose?.angle ?? cardView.angle,
          scaleX: 1.02,
          scaleY: 1.02,
          duration: 280,
          delay: index * 45,
          ease: "Cubic.InOut",
          onStart: () => {
            cardView.setDepth((pose?.depth ?? 500) + index);
          },
          onComplete: () => {
            completed += 1;
            if (completed !== overlayCards.length) {
              return;
            }

            overlayCards.forEach((overlayCard) => overlayCard.destroy());
            resolve();
          }
        });
      });
    });
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

  private isSelectedPlayValid(state: PublicGameState): boolean {
    if (state.phase !== "playing" || state.currentTurnPlayerId !== state.viewerPlayerId || this.busy) {
      return false;
    }

    if (this.selectedCardIds.size === 0) {
      return false;
    }

    const selectedCards = state.viewerHand.filter((card) => this.selectedCardIds.has(card.id));
    if (selectedCards.length !== this.selectedCardIds.size) {
      return false;
    }

    const firstRank = selectedCards[0]?.rank;
    if (firstRank === undefined || !selectedCards.every((card) => card.rank === firstRank)) {
      return false;
    }

    const currentSet = state.pile.currentSet;
    if (!currentSet) {
      return true;
    }

    if (selectedCards.length !== currentSet.count) {
      return false;
    }

    return firstRank > currentSet.rank;
  }

  private createButton(label: string, primary: boolean, onTap: () => void): Phaser.GameObjects.Container {
    const button = this.add.container(0, 0);
    const width = primary ? 172 : 132;
    const height = 48;
    const glow = this.add
      .ellipse(0, 6, width + 22, height + 18, toColorNumber(palette.primary), primary ? 0.22 : 0)
      .setVisible(primary);
    const background = this.add.graphics();
    const text = applyTextResolution(this.add
      .text(0, 0, label, {
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: "16px",
        color: primary ? palette.surfaceLowest : palette.text,
        fontStyle: "bold"
      })
      .setOrigin(0.5));

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
      this.requirementText = applyTextResolution(this.add
        .text(0, 0, "", {
          fontFamily: "Manrope, sans-serif",
          fontSize: "15px",
          color: palette.text,
          backgroundColor: palette.surfaceHigh,
          padding: { x: 12, y: 7 }
        })
        .setOrigin(0.5));
    }

    if (!this.statusBanner) {
      const background = this.add.graphics();
      const label = applyTextResolution(this.add
        .text(0, 0, "", {
          fontFamily: "Manrope, sans-serif",
          fontSize: "14px",
          color: palette.text,
          fontStyle: "bold",
          align: "center"
        })
        .setOrigin(0.5));
      this.statusBanner = this.add.container(0, 0, [background, label]);
      this.statusBanner.setData("background", background);
      this.statusBanner.setData("label", label);
    }

    if (!this.logText) {
      this.logText = applyTextResolution(this.add
        .text(0, 0, "", {
          fontFamily: "Manrope, sans-serif",
          fontSize: "12px",
          color: palette.mutedText,
          align: "left",
          wordWrap: { width: 228 }
        })
        .setOrigin(0, 0));
    }

    if (!this.debugHelpText) {
      this.debugHelpText = applyTextResolution(this.add
        .text(0, 0, "", {
          fontFamily: "Manrope, sans-serif",
          fontSize: "11px",
          color: palette.text,
          align: "left",
          wordWrap: { width: 228 }
        })
        .setOrigin(0, 0));
    }

    if (this.debugMode && !this.debugToggle) {
      this.debugToggle = this.createButton("Debug", false, () => {
        this.debugMenuVisible = !this.debugMenuVisible;
        this.renderState();
      });
      this.add.existing(this.debugToggle);
    }

    if (this.debugMode && !this.debugMenu && this.logText && this.debugHelpText) {
      const background = this.add.graphics();
      const title = applyTextResolution(this.add
        .text(0, 0, "Debug Menu", {
          fontFamily: "Space Grotesk, sans-serif",
          fontSize: "14px",
          color: palette.primary,
          fontStyle: "bold"
        })
        .setOrigin(0, 0));
      this.debugMenu = this.add.container(0, 0, [background, title, this.debugHelpText, this.logText]);
      this.debugMenu.setData("background", background);
      this.debugMenu.setData("title", title);
      this.debugMenu.setDepth(260);
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
    const canPlaySelection = this.isSelectedPlayValid(state);
    this.actionButton.setPosition(this.scale.width / 2, layout.actionBarY);
    this.actionButton.setDepth(200);
    this.updateButtonState(
      this.actionButton,
      isPassing ? canAct : canPlaySelection,
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
        const previousState = this.gameState;
        const nextState = await this.api.stepBotTurn();
        if (previousState) {
          await this.animateSeatPlayedCards(previousState, nextState);
        }
        this.gameState = nextState;
        this.renderState();
        this.scheduleBotTurnIfNeeded();
      } catch (error) {
        this.showBanner(error instanceof Error ? error.message : "Bot turn failed");
      }
    });
  }

  private setDebugVisibility(layout: TableLayout): void {
    if (!this.logText || !this.debugMenu || !this.debugHelpText) {
      return;
    }

    if (!this.debugMode) {
      this.debugMenu.setVisible(false);
      this.debugToggle?.setVisible(false);
      return;
    }

    this.debugToggle?.setVisible(true);
    this.debugToggle?.setPosition(layout.tableFrame.x + 74, layout.requirementY);
    this.updateButtonState(this.debugToggle, true);

    const visible = this.debugMenuVisible;
    const title = this.debugMenu.getData("title") as Phaser.GameObjects.Text;
    const background = this.debugMenu.getData("background") as Phaser.GameObjects.Graphics;
    const panelWidth = 252;
    const padding = 14;
    const anchorX = (this.debugToggle?.x ?? (layout.tableFrame.x + 74)) + 96;
    const anchorY = (this.debugToggle?.y ?? layout.requirementY) + 96;
    const shortcutsText = [
      "` : Toggle debug menu",
      "R : Toggle mock results",
      "X : Toggle mock exchange",
      "F : Fast-forward match"
    ].join("\n");

    this.debugHelpText.setText(shortcutsText);
    this.logText
      .setText((this.gameState?.log.slice(-5).map((entry) => entry.text).join("\n")) ?? "")
      .setWordWrapWidth(panelWidth - padding * 2, true);

    const contentHeight = Math.max(138, 68 + this.debugHelpText.height + this.logText.height);
    title.setPosition(-panelWidth / 2 + padding, -contentHeight / 2 + padding);
    this.debugHelpText.setPosition(-panelWidth / 2 + padding, -contentHeight / 2 + 38);
    this.logText.setPosition(-panelWidth / 2 + padding, 52);
    background.clear();
    background.fillStyle(toColorNumber(palette.surfaceHigh), 0.96);
    background.fillRoundedRect(-panelWidth / 2, -contentHeight / 2, panelWidth, contentHeight, 18);
    background.lineStyle(1.2, toColorNumber(palette.outlineVariant), 0.44);
    background.strokeRoundedRect(-panelWidth / 2, -contentHeight / 2, panelWidth, contentHeight, 18);
    background.lineStyle(1, toColorNumber(palette.outlineVariant), 0.28);
    background.strokeLineShape(new Phaser.Geom.Line(-panelWidth / 2 + padding, 34, panelWidth / 2 - padding, 34));

    this.debugMenu
      .setVisible(visible)
      .setAlpha(visible ? 1 : 0)
      .setPosition(anchorX, anchorY);
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

  }

  private renderState(): void {
    const state = this.gameState;
    if (!state) {
      return;
    }

    const resultsPayload = this.mockResultsEnabled ? buildMockResultsData(state) : state.phase === "finished" ? buildResultsData(state) : null;
    window.dispatchEvent(new CustomEvent("president:results", { detail: resultsPayload }));
    window.dispatchEvent(new CustomEvent("president:exchange", { detail: this.mockExchangeEnabled ? state : null }));

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

    this.setDebugVisibility(layout);
  }

  private syncDisplayedPile(state: PublicGameState): void {
    const currentSet = state.pile.currentSet;

    if (!currentSet) {
      if (this.displayedPileCards.length === 0) {
        this.lastSeenPileTimestamp = null;
        this.fadingDisplayedPile = false;
        return;
      }

      if (this.fadingDisplayedPile) {
        return;
      }

      this.fadingDisplayedPile = true;
      this.clearPileTimer?.remove(false);
      this.clearPileTimer = this.time.delayedCall(1060, () => {
        this.displayedPileCards = [];
        this.lastSeenPileTimestamp = null;
        this.fadingDisplayedPile = false;
        this.clearPileTimer = undefined;
        this.renderState();
      });
      return;
    }

    this.clearPileTimer?.remove(false);
    this.clearPileTimer = undefined;
    this.fadingDisplayedPile = false;

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
        const badgeText = applyTextResolution(this.add
          .text(0, -52, "", {
            fontFamily: "Manrope, sans-serif",
            fontSize: "10px",
            color: palette.text,
            fontStyle: "bold"
          })
          .setOrigin(0.5));
        const handFan = this.add.container(0, 0);
        const nameText = applyTextResolution(this.add
          .text(0, 48, player.name, {
            fontFamily: "Space Grotesk, sans-serif",
            fontSize: "13px",
            color: palette.text,
            fontStyle: "bold"
          })
          .setOrigin(0.5));
        const statusText = applyTextResolution(this.add
          .text(0, 86, "", {
            fontFamily: "Manrope, sans-serif",
            fontSize: "11px",
            color: palette.mutedText
          })
          .setOrigin(0.5));
        const container = this.add.container(seat.x, seat.y, [
          badgeBg,
          badgeText,
          ring,
          halo,
          handFan,
          nameText,
          statusText
        ]);
        widgets = { container, ring, halo, badgeBg, badgeText, nameText, handFan, statusText };
        this.seatWidgets.set(player.id, widgets);
      }

      if (!widgets) {
        return;
      }

      const badge = this.describeSeatBadge(player, state.players.length);
      widgets.container.setPosition(seat.x, seat.y);
      widgets.nameText.setText(player.name);
      const status = this.describeStatus(player, false);
      widgets.statusText.setText(status);
      widgets.statusText.setVisible(status.length > 0);
      widgets.badgeText.setText(badge.text);
      widgets.badgeBg.setFillStyle(toColorNumber(badge.fill), badge.alpha);
      widgets.badgeText.setColor(badge.color);
      widgets.halo.setAlpha(player.status === "finished" ? 0.55 : 1);
      widgets.halo.setScale(player.isCurrentTurn ? 1.08 : 1);
      widgets.ring.setStrokeStyle(2.5, toColorNumber(badge.ring), player.isCurrentTurn ? 1 : 0.55);
      widgets.ring.setScale(player.isCurrentTurn ? 1.12 : 1);
      widgets.handFan.removeAll(true);
      if (!isViewer && player.handCount > 0) {
        const handBackPoses = this.buildSeatHandBackPoses(seat, layout.center, player.handCount);
        handBackPoses.forEach((pose, index) => {
          const backCard = this.createBackCard(pose.localX, pose.localY, pose.angle);
          backCard.setAlpha(player.status === "finished" ? 0.28 : 0.92 - index * 0.08);
          widgets.handFan.add(backCard);
        });
      }
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
      const poses = this.computePilePoses(layout, visibleCards.map((entry) => entry.key));

      visibleCards.forEach((entry, index) => {
        const { card } = entry;
        const pose = poses[index];
        const cardView = new CardView(this, card, pose.x, pose.y);
        cardView.syncPose(pose.x, pose.y, pose.angle, 1.08, pose.depth);
        cardView.setSelected(false);
        cardView.setAvailabilityState(true, false);
        children.push(cardView);
      });
    } else {
      const emptyText = applyTextResolution(this.add
        .text(layout.center.x, layout.center.y - 4, "New Round", {
          fontFamily: "Space Grotesk, sans-serif",
          fontSize: "28px",
          color: palette.primary,
          fontStyle: "bold"
        })
        .setOrigin(0.5));
      const helperText = applyTextResolution(this.add
        .text(layout.center.x, layout.center.y + 34, "Play any valid set to lead.", {
          fontFamily: "Manrope, sans-serif",
          fontSize: "13px",
          color: palette.mutedText
        })
        .setOrigin(0.5));
      children.push(emptyText, helperText);
    }

    this.centerGroup = this.add.container(0, 0, children);

    if (this.fadingDisplayedPile && !state.pile.currentSet) {
      this.centerGroup.setAlpha(1);
      this.tweens.killTweensOf(this.centerGroup);
      this.tweens.add({
        targets: this.centerGroup,
        alpha: 0,
        delay: 780,
        duration: 260,
        ease: "Quad.In"
      });
    }
  }

  private renderHand(): void {
    const state = this.gameState;
    if (!state) {
      return;
    }

    const existingCards = new Map(this.handCards.map((card) => [card.card.id, card]));
    const nextHandCards: CardView[] = [];

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
      const x = startX + spread * index;
      const scale = baseScale * (selected ? 1.06 : 1);
      const depth = 100 + index + (selected ? 1000 : 0);
      const existingCard = existingCards.get(card.id);
      const cardView = existingCard ?? new CardView(this, card, x, y);

      if (existingCard) {
        existingCards.delete(card.id);
      } else {
        cardView.syncPose(x, y, angle, scale, depth);
      }

      cardView.setHitAreaProfile(
        selected ? 72 : index === 0 || index === fanSize - 1 ? Math.max(sharedHitWidth, 40) : sharedHitWidth,
        Phaser.Math.Clamp(Math.sin(Phaser.Math.DegToRad(angle)) * 16, -16, 16)
      );
      cardView.setSelected(selected);
      cardView.setAvailabilityState(selectable, selected);
      if (existingCard) {
        cardView.tweenToPose(x, y, angle, scale, depth);
      }
      nextHandCards.push(cardView);
    });

    existingCards.forEach((cardView) => cardView.destroy());
    this.handCards = nextHandCards;

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
