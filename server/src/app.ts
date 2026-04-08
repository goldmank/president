import express from "express";
import cors from "cors";
import { GameManager } from "./game/GameManager.js";

export function createApp(): express.Express {
  const app = express();
  const games = new GameManager();

  app.use(cors());
  app.use(express.json());

  app.get("/health", (_request, response) => {
    response.json({ ok: true });
  });

  app.post("/game", (request, response) => {
    response.json(games.createNewGame(request.body?.playerCount));
  });

  app.get("/game", (_request, response) => {
    response.json(games.getState());
  });

  app.post("/game/action", (request, response) => {
    try {
      const nextState = games.submit(request.body);
      response.json(nextState);
    } catch (error) {
      response.status(400).json({
        error: error instanceof Error ? error.message : "Unknown error"
      });
    }
  });

  app.post("/game/bot-turn", (_request, response) => {
    try {
      const nextState = games.stepBotTurn();
      response.json(nextState);
    } catch (error) {
      response.status(400).json({
        error: error instanceof Error ? error.message : "Unknown error"
      });
    }
  });

  return app;
}
