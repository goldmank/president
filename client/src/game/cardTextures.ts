import Phaser from "phaser";
import type { Card, Suit } from "@president/shared";
import { rankLabelMap } from "@president/shared";
import { palette, toColorNumber } from "./theme";
import { applyTextResolution } from "./text";

export const CARD_WIDTH = 72;
export const CARD_HEIGHT = 104;

export type CardVisualState = "normal" | "selected" | "disabled";

interface CardTexturePalette {
  background: string;
  border: string;
  borderAlpha: number;
  innerBorder: string;
  innerBorderAlpha: number;
  text: string;
  pipAlpha: number;
}

function getTextureScale(): number {
  if (typeof window === "undefined") {
    return 2;
  }

  return Math.max(2, Math.min(window.devicePixelRatio || 1, 3));
}

function getSuitSymbol(suit: Suit): string {
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

function getSuitColor(card: Card): string {
  if (card.suit === "joker") {
    return palette.primary;
  }

  return card.suit === "hearts" || card.suit === "diamonds" ? palette.danger : palette.text;
}

function getCardPalette(card: Card, state: CardVisualState): CardTexturePalette {
  const suitColor = getSuitColor(card);

  if (state === "disabled") {
    return {
      background: palette.surfaceContainer,
      border: palette.outline,
      borderAlpha: 0.9,
      innerBorder: palette.outlineVariant,
      innerBorderAlpha: 0.38,
      text: palette.mutedText,
      pipAlpha: 0.55
    };
  }

  if (state === "selected") {
    return {
      background: palette.surfaceBright,
      border: palette.primary,
      borderAlpha: 1,
      innerBorder: palette.primary,
      innerBorderAlpha: 0.8,
      text: palette.primary,
      pipAlpha: 1
    };
  }

  return {
    background: palette.surfaceHighest,
    border: palette.outlineVariant,
    borderAlpha: 0.8,
    innerBorder: palette.outlineVariant,
    innerBorderAlpha: 0.32,
    text: suitColor,
    pipAlpha: 0.85
  };
}

function getTextureKey(card: Card, state: CardVisualState): string {
  return `card-face-${card.rank}-${card.suit}-${state}-${getTextureScale()}x`;
}

export function ensureCardTexture(scene: Phaser.Scene, card: Card, state: CardVisualState): string {
  const key = getTextureKey(card, state);
  if (scene.textures.exists(key)) {
    return key;
  }

  const scale = getTextureScale();
  const width = CARD_WIDTH * scale;
  const height = CARD_HEIGHT * scale;
  const rankLabel = rankLabelMap[card.rank];
  const suitSymbol = getSuitSymbol(card.suit);
  const colors = getCardPalette(card, state);
  const rankFontSize = (rankLabel === "10" ? 14 : rankLabel === "JKR" ? 11 : 18) * scale;
  const pipFontSize = (card.suit === "joker" ? 26 : 32) * scale;
  const texture = scene.textures.addDynamicTexture(key, width, height);
  if (!texture) {
    throw new Error(`Failed to create card texture: ${key}`);
  }

  texture.fill(toColorNumber(colors.background));

  const background = scene.add
    .rectangle(width / 2, height / 2, width, height, toColorNumber(colors.background))
    .setStrokeStyle(1.5 * scale, toColorNumber(colors.border), colors.borderAlpha);
  const innerFrame = scene.add
    .rectangle(width / 2, height / 2, 62 * scale, 94 * scale)
    .setStrokeStyle(scale, toColorNumber(colors.innerBorder), colors.innerBorderAlpha);
  const cornerRank = applyTextResolution(
    scene.add
      .text(13 * scale, 12 * scale, rankLabel, {
        color: colors.text,
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: `${rankFontSize}px`,
        fontStyle: "bold"
      })
      .setOrigin(0, 0)
  );
  const centerPip = applyTextResolution(
    scene.add
      .text(width / 2, height / 2 + 4 * scale, suitSymbol, {
        color: colors.text,
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: `${pipFontSize}px`,
        fontStyle: "bold"
      })
      .setOrigin(0.5)
      .setAlpha(colors.pipAlpha)
  );
  const mirroredRank = applyTextResolution(
    scene.add
      .text(width - 19 * scale, height - 23 * scale, rankLabel, {
        color: colors.text,
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: `${rankFontSize}px`,
        fontStyle: "bold"
      })
      .setOrigin(1, 1)
      .setAngle(180)
  );

  texture.draw([background, innerFrame, cornerRank, centerPip, mirroredRank]);

  background.destroy();
  innerFrame.destroy();
  cornerRank.destroy();
  centerPip.destroy();
  mirroredRank.destroy();

  return key;
}
