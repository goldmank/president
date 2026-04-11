import Phaser from "phaser";
import type { Card, RankValue, Suit } from "@president/shared";
import { rankLabelMap } from "@president/shared";
import { palette, toColorNumber } from "./theme";
import { applyTextResolution } from "./text";

export const CARD_WIDTH = 72;
export const CARD_HEIGHT = 102;

const STANDARD_CARD_HEIGHT = 930;
const STANDARD_CARD_WIDTH = 655;

const suitAssetMap: Record<Exclude<Suit, "joker">, string> = {
  clubs: "Clovers",
  diamonds: "Tiles",
  hearts: "Hearts",
  spades: "Pikes"
};

const rankAssetMap: Record<Exclude<RankValue, 16>, string> = {
  3: "3",
  4: "4",
  5: "5",
  6: "6",
  7: "7",
  8: "8",
  9: "9",
  10: "10",
  11: "Jack",
  12: "Queen",
  13: "King",
  14: "A",
  15: "2"
};

function getTextureScale(): number {
  if (typeof window === "undefined") {
    return 2;
  }

  return Math.max(1, Math.min(window.devicePixelRatio || 1, 3));
}

function getCardAssetFilename(card: Card): string | null {
  if (card.suit === "joker" || card.rank === 16) {
    return null;
  }

  const suit = suitAssetMap[card.suit];
  const rank = rankAssetMap[card.rank];

  if (card.suit === "hearts" && card.rank === 6) {
    return "Heats_6_white.png";
  }

  return `${suit}_${rank}_white.png`;
}

export function preloadCardTextures(scene: Phaser.Scene): void {
  for (const suit of Object.keys(suitAssetMap) as Array<Exclude<Suit, "joker">>) {
    for (const rank of Object.keys(rankAssetMap).map(Number) as Array<Exclude<RankValue, 16>>) {
      const card: Card = {
        id: `${rank}-${suit}`,
        rank,
        suit
      };
      const filename = getCardAssetFilename(card);
      const textureKey = getStandardCardTextureKey(card);

      if (!filename || scene.textures.exists(textureKey)) {
        continue;
      }

      scene.load.image(textureKey, `/cards/white/${filename}`);
    }
  }
}

function getStandardCardTextureKey(card: Card): string {
  return `card-front-${card.rank}-${card.suit}`;
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

function ensureJokerTexture(scene: Phaser.Scene): string {
  const key = `card-front-joker-${getTextureScale()}x`;
  if (scene.textures.exists(key)) {
    return key;
  }

  const scale = getTextureScale();
  const width = CARD_WIDTH * scale;
  const height = Math.round((CARD_HEIGHT / STANDARD_CARD_HEIGHT) * 930 * scale);
  const rankLabel = rankLabelMap[16];
  const texture = scene.textures.addDynamicTexture(key, width, height);
  if (!texture) {
    throw new Error(`Failed to create joker texture: ${key}`);
  }

  texture.fill(toColorNumber(palette.surfaceHighest));

  const background = scene.add
    .rectangle(width / 2, height / 2, width, height, toColorNumber(palette.surfaceHighest))
    .setStrokeStyle(1.5 * scale, toColorNumber(palette.primary), 0.95);
  const innerFrame = scene.add
    .rectangle(width / 2, height / 2, 62 * scale, 92 * scale)
    .setStrokeStyle(scale, toColorNumber(palette.primaryDim), 0.5);
  const cornerRank = applyTextResolution(
    scene.add
      .text(11 * scale, 10 * scale, rankLabel, {
        color: palette.primary,
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: `${11 * scale}px`,
        fontStyle: "bold"
      })
      .setOrigin(0, 0)
  );
  const centerPip = applyTextResolution(
    scene.add
      .text(width / 2, height / 2 + 2 * scale, getSuitSymbol("joker"), {
        color: palette.primary,
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: `${26 * scale}px`,
        fontStyle: "bold"
      })
      .setOrigin(0.5)
  );
  const mirroredRank = applyTextResolution(
    scene.add
      .text(width - 17 * scale, height - 21 * scale, rankLabel, {
        color: palette.primary,
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: `${11 * scale}px`,
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

export function getCardTextureKey(scene: Phaser.Scene, card: Card): string {
  const filename = getCardAssetFilename(card);

  if (!filename) {
    return ensureJokerTexture(scene);
  }

  return getStandardCardTextureKey(card);
}

export function getCardDisplaySize(): { width: number; height: number } {
  return {
    width: CARD_WIDTH,
    height: Math.round((CARD_WIDTH / STANDARD_CARD_WIDTH) * STANDARD_CARD_HEIGHT)
  };
}
