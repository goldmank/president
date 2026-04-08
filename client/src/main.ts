import Phaser from "phaser";
import { GameScene } from "./game/scenes/GameScene";

const app = document.getElementById("app");
if (!app) {
  throw new Error("Missing app container");
}

const config: Phaser.Types.Core.GameConfig = {
  type: Phaser.AUTO,
  parent: app,
  backgroundColor: "#0f172a",
  scale: {
    mode: Phaser.Scale.RESIZE,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: window.innerWidth,
    height: window.innerHeight
  },
  scene: [GameScene]
};

new Phaser.Game(config);
