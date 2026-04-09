import Phaser from "phaser";

function getTextResolution(): number {
  if (typeof window === "undefined") {
    return 1;
  }

  return Math.max(1, Math.min(window.devicePixelRatio || 1, 3));
}

export function applyTextResolution<T extends Phaser.GameObjects.Text>(text: T): T {
  text.setResolution(getTextResolution());
  return text;
}
