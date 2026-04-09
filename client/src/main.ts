import Phaser from "phaser";
import { GameScene } from "./game/scenes/GameScene";
import { ResultsOverlay, type MatchResultsData } from "./results/resultsOverlay";
import { ExchangeOverlay, buildExchangePreviewData, buildMockExchangeData } from "./results/exchangeOverlay";
import type { PublicGameState } from "@president/shared";

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

let game: Phaser.Game;
let exchangeOverlaySource: "scene-mock" | "results-flow" | null = null;
const exchangeOverlay = new ExchangeOverlay(
  app,
  (mode) => {
    const scene = game.scene.getScene("game") as GameScene;
    exchangeOverlay.hide();
    exchangeOverlaySource = null;
    if (mode === "mock") {
      scene.setMockExchangeEnabled(false);
      return;
    }

    scene.startNewGame();
  },
  (mode) => {
    const scene = game.scene.getScene("game") as GameScene;
    exchangeOverlay.hide();
    exchangeOverlaySource = null;
    if (mode === "mock") {
      scene.setMockExchangeEnabled(false);
    }
  }
);
const resultsOverlay = new ResultsOverlay(app, (mode) => {
  const scene = game.scene.getScene("game") as GameScene;
  const state = scene.getCurrentState();
  if (!state) {
    return;
  }
  resultsOverlay.hide();
  exchangeOverlaySource = "results-flow";
  exchangeOverlay.show(mode === "mock" ? buildMockExchangeData(state) : buildExchangePreviewData(state));
  if (mode === "mock") {
    scene.setMockResultsEnabled(false);
  }
});

window.addEventListener("president:results", (event: Event) => {
  const { detail } = event as CustomEvent<MatchResultsData | null>;
  if (!detail) {
    resultsOverlay.hide();
    return;
  }

  resultsOverlay.show(detail);
});

window.addEventListener("president:exchange", (event: Event) => {
  const { detail } = event as CustomEvent<PublicGameState | null>;
  if (!detail) {
    if (exchangeOverlaySource === "scene-mock") {
      exchangeOverlay.hide();
      exchangeOverlaySource = null;
    }
    return;
  }

  resultsOverlay.hide();
  exchangeOverlaySource = "scene-mock";
  exchangeOverlay.show(buildMockExchangeData(detail));
});

game = new Phaser.Game(config);
