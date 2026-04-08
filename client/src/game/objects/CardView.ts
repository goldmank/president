import Phaser from "phaser";
import type { Card, Suit } from "@president/shared";
import { rankLabelMap } from "@president/shared";
import { palette, toColorNumber } from "../theme";

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
  }
}

export class CardView extends Phaser.GameObjects.Container {
  public readonly card: Card;
  private readonly background: Phaser.GameObjects.Rectangle;
  private readonly innerFrame: Phaser.GameObjects.Rectangle;
  private readonly cornerRank: Phaser.GameObjects.Text;
  private readonly centerPip: Phaser.GameObjects.Text;
  private readonly mirroredRank: Phaser.GameObjects.Text;
  private readonly suitColor: string;
  private readonly suitMutedColor = palette.mutedText;
  private readonly hitPolygon = new Phaser.Geom.Polygon([
    -36, -52,
    36, -52,
    36, 52,
    -36, 52
  ]);
  private interactiveForSelection = true;

  public constructor(scene: Phaser.Scene, card: Card, x: number, y: number) {
    super(scene, x, y);
    this.card = card;
    this.suitColor = card.suit === "hearts" || card.suit === "diamonds" ? palette.danger : palette.text;
    const suitSymbol = getSuitSymbol(card.suit);
    const rankLabel = rankLabelMap[card.rank];

    this.background = scene
      .add.rectangle(0, 0, 72, 104, toColorNumber(palette.surfaceHighest))
      .setStrokeStyle(1.5, toColorNumber(palette.outlineVariant), 0.8);
    this.innerFrame = scene.add
      .rectangle(0, 0, 62, 94)
      .setStrokeStyle(1, toColorNumber(palette.outlineVariant), 0.32);
    this.cornerRank = scene.add
      .text(-23, -40, rankLabel, {
        color: this.suitColor,
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: rankLabel === "10" ? "14px" : "18px",
        fontStyle: "bold"
      })
      .setOrigin(0, 0);
    this.centerPip = scene.add
      .text(0, 4, suitSymbol, {
        color: this.suitColor,
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: "32px",
        fontStyle: "bold"
      })
      .setOrigin(0.5);
    this.mirroredRank = scene.add
      .text(17, 29, rankLabel, {
        color: this.suitColor,
        fontFamily: "Space Grotesk, sans-serif",
        fontSize: rankLabel === "10" ? "14px" : "18px",
        fontStyle: "bold"
      })
      .setOrigin(1, 1)
      .setAngle(180);

    this.add([
      this.background,
      this.innerFrame,
      this.cornerRank,
      this.centerPip,
      this.mirroredRank
    ]);
    this.setSize(72, 104);
    scene.add.existing(this);
  }

  public setSelected(selected: boolean): void {
    void selected;
  }

  public setHitAreaProfile(width: number, slant: number): void {
    const halfWidth = width / 2;
    this.hitPolygon.setTo([
      -halfWidth + slant,
      -52,
      halfWidth + slant,
      -52,
      halfWidth - slant,
      52,
      -halfWidth - slant,
      52
    ]);
  }

  public setAvailabilityState(selectable: boolean, selected: boolean): void {
    this.interactiveForSelection = selectable || selected;
    const disabled = !selectable && !selected;
    const textColor = disabled ? this.suitMutedColor : selected ? palette.primary : this.suitColor;

    this.setAlpha(1);
    this.background.setFillStyle(
      toColorNumber(disabled ? palette.surfaceContainer : selected ? palette.surfaceBright : palette.surfaceHighest)
    );
    this.background.setStrokeStyle(
      2,
      toColorNumber(disabled ? palette.outline : selected ? palette.primary : palette.outlineVariant),
      disabled ? 0.9 : selected ? 1 : 0.8
    );
    this.innerFrame.setStrokeStyle(
      1,
      toColorNumber(disabled ? palette.outlineVariant : selected ? palette.primary : palette.outlineVariant),
      disabled ? 0.38 : selected ? 0.8 : 0.32
    );
    this.cornerRank.setColor(textColor);
    this.centerPip.setColor(textColor);
    this.centerPip.setAlpha(disabled ? 0.55 : selected ? 1 : 0.85);
    this.mirroredRank.setColor(textColor);
  }

  public containsScreenPoint(x: number, y: number): boolean {
    if (!this.interactiveForSelection) {
      return false;
    }

    const cos = Math.cos(this.rotation);
    const sin = Math.sin(this.rotation);
    const transformedPoints: number[] = [];

    for (let index = 0; index < this.hitPolygon.points.length; index += 1) {
      const point = this.hitPolygon.points[index];
      const scaledX = point.x * this.scaleX;
      const scaledY = point.y * this.scaleY;
      const rotatedX = scaledX * cos - scaledY * sin;
      const rotatedY = scaledX * sin + scaledY * cos;
      transformedPoints.push(this.x + rotatedX, this.y + rotatedY);
    }

    return Phaser.Geom.Polygon.Contains(new Phaser.Geom.Polygon(transformedPoints), x, y);
  }
}
