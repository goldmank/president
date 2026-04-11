import Phaser from "phaser";
import type { Card } from "@president/shared";
import { getCardDisplaySize, getCardTextureKey } from "../cardTextures";
import { palette, toColorNumber } from "../theme";

export class CardView extends Phaser.GameObjects.Container {
  public readonly card: Card;
  private readonly face: Phaser.GameObjects.Image;
  private readonly selectedFrame: Phaser.GameObjects.Graphics;
  private readonly disabledVeil: Phaser.GameObjects.Graphics;
  private readonly disabledFrame: Phaser.GameObjects.Graphics;
  private readonly cardWidth: number;
  private readonly cardHeight: number;
  private readonly hitPolygon = new Phaser.Geom.Polygon([
    -36, -51,
    36, -51,
    36, 51,
    -36, 51
  ]);
  private interactiveForSelection = true;
  private poseTween?: Phaser.Tweens.Tween;

  public constructor(scene: Phaser.Scene, card: Card, x: number, y: number) {
    super(scene, x, y);
    this.card = card;
    const { width, height } = getCardDisplaySize();
    this.cardWidth = width;
    this.cardHeight = height;
    this.face = scene.add.image(0, 0, getCardTextureKey(scene, card));
    this.face.setDisplaySize(this.cardWidth, this.cardHeight);
    this.selectedFrame = scene.add.graphics().setVisible(false);
    this.disabledVeil = scene.add.graphics().setVisible(false);
    this.disabledFrame = scene.add.graphics().setVisible(false);
    this.redrawSelectedFrame();
    this.redrawDisabledState();
    this.add([this.face, this.disabledVeil, this.disabledFrame, this.selectedFrame]);
    this.setSize(this.cardWidth, this.cardHeight);
    scene.add.existing(this);
  }

  private redrawSelectedFrame(): void {
    const inset = 3;
    this.selectedFrame.clear();
    this.selectedFrame.lineStyle(2, toColorNumber(palette.primary), 1);
    this.selectedFrame.strokeRoundedRect(
      -this.cardWidth / 2 + inset,
      -this.cardHeight / 2 + inset,
      this.cardWidth - inset * 2,
      this.cardHeight - inset * 2,
      8
    );
  }

  private redrawDisabledState(): void {
    const inset = 2;
    this.disabledVeil.clear();
    this.disabledVeil.fillStyle(toColorNumber(palette.surfaceContainer), 0.34);
    this.disabledVeil.fillRoundedRect(-this.cardWidth / 2, -this.cardHeight / 2, this.cardWidth, this.cardHeight, 8);
    this.disabledFrame.clear();
    this.disabledFrame.lineStyle(2, toColorNumber(palette.outline), 0.95);
    this.disabledFrame.strokeRoundedRect(
      -this.cardWidth / 2 + inset,
      -this.cardHeight / 2 + inset,
      this.cardWidth - inset * 2,
      this.cardHeight - inset * 2,
      8
    );
  }

  public setSelected(selected: boolean): void {
    this.setData("selected", selected);
  }

  public syncPose(x: number, y: number, angle: number, scale: number, depth: number): void {
    this.poseTween?.stop();
    this.poseTween = undefined;
    this.setPosition(x, y);
    this.setAngle(angle);
    this.setScale(scale);
    this.setDepth(depth);
  }

  public tweenToPose(x: number, y: number, angle: number, scale: number, depth: number): void {
    this.setDepth(depth);
    this.poseTween?.stop();
    this.poseTween = this.scene.tweens.add({
      targets: this,
      x,
      y,
      angle,
      scaleX: scale,
      scaleY: scale,
      duration: 170,
      ease: "Quad.Out",
      onComplete: () => {
        this.poseTween = undefined;
      }
    });
  }

  public setHitAreaProfile(width: number, slant: number): void {
    const halfWidth = width / 2;
    this.hitPolygon.setTo([
      -halfWidth + slant,
      -this.cardHeight / 2,
      halfWidth + slant,
      -this.cardHeight / 2,
      halfWidth - slant,
      this.cardHeight / 2,
      -halfWidth - slant,
      this.cardHeight / 2
    ]);
  }

  public setAvailabilityState(selectable: boolean, selected: boolean): void {
    this.interactiveForSelection = selectable || selected;
    const disabled = !selectable && !selected;
    this.face.clearTint();
    this.face.setDisplaySize(this.cardWidth, this.cardHeight);
    this.selectedFrame.setVisible(selected);
    this.disabledVeil.setVisible(disabled);
    this.disabledFrame.setVisible(disabled);
    this.face.setTint(disabled ? toColorNumber(palette.outline) : 0xffffff);
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
