import Phaser from "phaser";
import { GameScene } from "./game/scenes/GameScene";
import { ResultsOverlay, type MatchResultsData } from "./results/resultsOverlay";
import { ExchangeOverlay, buildExchangePreviewData, buildMockExchangeData } from "./results/exchangeOverlay";
import type { PublicGameState } from "@president/shared";

const app = document.getElementById("app");
if (!app) {
  throw new Error("Missing app container");
}

function getRenderResolution(): number {
  return Math.max(1, Math.min(window.devicePixelRatio || 1, 3));
}

function isAndroidDevice(): boolean {
  return /android/i.test(navigator.userAgent);
}

function useHighDpiCanvas(): boolean {
  return false;
}

interface RenderDiagnostics {
  renderer: string;
  dpr: number;
  inner: string;
  visualViewport: string;
  canvasCss: string;
  canvasBacking: string;
  rect: string;
  scale: string;
  drawingBuffer: string;
  cameraZoom: string;
  cameraViewport: string;
  cameraWorldView: string;
  cameraScroll: string;
}

function getRendererType(): number {
  return Phaser.AUTO;
}

function shouldShowRenderDiagnostics(): boolean {
  return import.meta.env.DEV && new URLSearchParams(window.location.search).get("renderDiagnostics") === "1";
}

function getRendererLabel(game: Phaser.Game): string {
  switch (game.renderer.type) {
    case Phaser.CANVAS:
      return "CANVAS";
    case Phaser.WEBGL:
      return "WEBGL";
    default:
      return String(game.renderer.type);
  }
}

function collectRenderDiagnostics(game: Phaser.Game): RenderDiagnostics {
  const canvas = game.canvas;
  const rect = canvas.getBoundingClientRect();
  const viewport = window.visualViewport;
  const webglRenderer = game.renderer as Phaser.Renderer.WebGL.WebGLRenderer & {
    gl?: WebGLRenderingContext;
  };
  const drawingBuffer =
    game.renderer.type === Phaser.WEBGL && webglRenderer.gl
      ? `${webglRenderer.gl.drawingBufferWidth}x${webglRenderer.gl.drawingBufferHeight}`
      : "-";
  let cameraZoom = "-";
  let cameraViewport = "-";
  let cameraWorldView = "-";
  let cameraScroll = "-";

  try {
    const scene = game.scene.getScene("game");
    const camera = scene.cameras.main;
    cameraZoom = `${camera.zoom}`;
    cameraViewport = `${Math.round(camera.width)}x${Math.round(camera.height)}`;
    cameraWorldView = `${Math.round(camera.worldView.width)}x${Math.round(camera.worldView.height)}`;
    cameraScroll = `${Math.round(camera.scrollX)},${Math.round(camera.scrollY)}`;
  } catch {
    // Scene not ready yet.
  }

  return {
    renderer: getRendererLabel(game),
    dpr: Number(window.devicePixelRatio || 1),
    inner: `${window.innerWidth}x${window.innerHeight}`,
    visualViewport: viewport ? `${Math.round(viewport.width)}x${Math.round(viewport.height)} @ ${viewport.scale.toFixed(2)}` : "-",
    canvasCss: `${canvas.style.width || canvas.clientWidth}px x ${canvas.style.height || canvas.clientHeight}px`,
    canvasBacking: `${canvas.width}x${canvas.height}`,
    rect: `${Math.round(rect.width)}x${Math.round(rect.height)} @ ${Math.round(rect.left)},${Math.round(rect.top)}`,
    scale: `${Math.round(game.scale.width)}x${Math.round(game.scale.height)}`,
    drawingBuffer,
    cameraZoom,
    cameraViewport,
    cameraWorldView,
    cameraScroll
  };
}

function createDiagnosticsOverlay(parent: HTMLElement, game: Phaser.Game): void {
  const overlay = document.createElement("pre");
  overlay.setAttribute("id", "render-diagnostics");
  overlay.style.position = "fixed";
  overlay.style.top = "6px";
  overlay.style.right = "6px";
  overlay.style.zIndex = "9999";
  overlay.style.margin = "0";
  overlay.style.padding = "8px 10px";
  overlay.style.maxWidth = "min(220px, calc(100vw - 24px))";
  overlay.style.whiteSpace = "pre-wrap";
  overlay.style.wordBreak = "break-word";
  overlay.style.borderRadius = "8px";
  overlay.style.background = "rgba(0,0,0,0.82)";
  overlay.style.color = "#ffd700";
  overlay.style.font = "10px/1.3 ui-monospace, SFMono-Regular, Menlo, monospace";
  overlay.style.pointerEvents = "none";
  overlay.style.border = "1px solid rgba(255,215,0,0.35)";
  parent.appendChild(overlay);

  const updateDiagnostics = () => {
    const diagnostics = collectRenderDiagnostics(game);
    overlay.textContent = [
      `renderer: ${diagnostics.renderer}`,
      `dpr: ${diagnostics.dpr}`,
      `inner: ${diagnostics.inner}`,
      `visualViewport: ${diagnostics.visualViewport}`,
      `canvas css: ${diagnostics.canvasCss}`,
      `canvas backing: ${diagnostics.canvasBacking}`,
      `canvas rect: ${diagnostics.rect}`,
      `phaser scale: ${diagnostics.scale}`,
      `drawingBuffer: ${diagnostics.drawingBuffer}`,
      `camera zoom: ${diagnostics.cameraZoom}`,
      `camera viewport: ${diagnostics.cameraViewport}`,
      `camera worldView: ${diagnostics.cameraWorldView}`,
      `camera scroll: ${diagnostics.cameraScroll}`
    ].join("\n");
    console.log("[render-diagnostics]", diagnostics);
  };

  updateDiagnostics();
  window.addEventListener("resize", updateDiagnostics);
  window.visualViewport?.addEventListener("resize", updateDiagnostics);
  game.scale.on("resize", updateDiagnostics);
  window.setInterval(updateDiagnostics, 1500);
}

const config = {
  type: getRendererType(),
  parent: app,
  backgroundColor: "#0f172a",
  autoRound: true,
  render: {
    antialias: true,
    antialiasGL: true,
    pixelArt: false,
    roundPixels: false
  },
  scale: useHighDpiCanvas()
    ? {
        mode: Phaser.Scale.NONE,
        autoCenter: Phaser.Scale.NO_CENTER,
        width: Math.round(window.innerWidth * getRenderResolution()),
        height: Math.round(window.innerHeight * getRenderResolution())
      }
    : {
        mode: Phaser.Scale.RESIZE,
        autoCenter: Phaser.Scale.CENTER_BOTH,
        width: window.innerWidth,
        height: window.innerHeight
      },
  scene: [GameScene]
} as Phaser.Types.Core.GameConfig;

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
window.__PRESIDENT_RENDER_SCALE__ = useHighDpiCanvas() ? getRenderResolution() : 1;

if (shouldShowRenderDiagnostics()) {
  createDiagnosticsOverlay(app, game);
}
