import Phaser from "phaser";
import type { Card } from "@president/shared";
import { CARD_HEIGHT, CARD_WIDTH, ensureCardTexture, type CardVisualState } from "../cardTextures";

export class CardView extends Phaser.GameObjects.Container {
  public readonly card: Card;
  private readonly face: Phaser.GameObjects.Image;
  private readonly hitPolygon = new Phaser.Geom.Polygon([
    -36, -52,
    36, -52,
    36, 52,
    -36, 52
  ]);
  private interactiveForSelection = true;
  private poseTween?: Phaser.Tweens.Tween;

  public constructor(scene: Phaser.Scene, card: Card, x: number, y: number) {
    super(scene, x, y);
    this.card = card;
    this.face = scene.add.image(0, 0, ensureCardTexture(scene, card, "normal"));
    this.face.setDisplaySize(CARD_WIDTH, CARD_HEIGHT);
    this.add(this.face);
    this.setSize(CARD_WIDTH, CARD_HEIGHT);
    scene.add.existing(this);
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
    const state: CardVisualState = !selectable && !selected ? "disabled" : selected ? "selected" : "normal";
    this.face.setTexture(ensureCardTexture(this.scene, this.card, state));
    this.face.setDisplaySize(CARD_WIDTH, CARD_HEIGHT);
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
