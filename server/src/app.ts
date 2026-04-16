import express from "express";
import cors from "cors";
import { GameManager } from "./game/GameManager.js";
import { PrivateRoomService } from "./multiplayer/PrivateRoomService.js";
import { RankedMatchmakingService } from "./multiplayer/RankedMatchmakingService.js";

export function createApp(
  matchmaking: RankedMatchmakingService,
  privateRooms: PrivateRoomService
): express.Express {
  const app = express();
  const games = new GameManager();

  app.use(cors());
  app.use(express.json());
  app.use((request, response, next) => {
    const startedAt = Date.now();
    const body =
      request.method === "GET" || request.body == null
        ? ""
        : ` body=${JSON.stringify(request.body)}`;

    console.log(
      `[http] -> ${request.method} ${request.originalUrl}${body}`
    );

    response.on("finish", () => {
      const durationMs = Date.now() - startedAt;
      console.log(
        `[http] <- ${request.method} ${request.originalUrl} ${response.statusCode} ${durationMs}ms`
      );
    });

    next();
  });

  app.get("/health", (_request, response) => {
    response.json({ ok: true });
  });

  app.post("/game", (request, response) => {
    response.json(
      games.createNewGame(request.body?.playerCount, request.body?.rules)
    );
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

  app.post("/game/fast-forward", (_request, response) => {
    try {
      const nextState = games.fastForward();
      response.json(nextState);
    } catch (error) {
      response.status(400).json({
        error: error instanceof Error ? error.message : "Unknown error"
      });
    }
  });

  app.post("/game/next-round", (_request, response) => {
    try {
      const nextState = games.startNextRound();
      response.json(nextState);
    } catch (error) {
      response.status(400).json({
        error: error instanceof Error ? error.message : "Unknown error"
      });
    }
  });

  app.get("/game/exchange-preview", (_request, response) => {
    try {
      response.json(games.getExchangePreview());
    } catch (error) {
      response.status(400).json({
        error: error instanceof Error ? error.message : "Unknown error"
      });
    }
  });

  app.post("/ranked/queue", (request, response) => {
    const userId = request.body?.userId;
    const displayName = request.body?.displayName;
    const rankScore = request.body?.rankScore;
    const photoUrl = request.body?.photoUrl;
    if (typeof userId !== "string" || userId.trim().length === 0) {
      response.status(400).json({ error: "userId is required" });
      return;
    }
    if (typeof displayName !== "string" || displayName.trim().length === 0) {
      response.status(400).json({ error: "displayName is required" });
      return;
    }
    if (typeof rankScore !== "number") {
      response.status(400).json({ error: "rankScore is required" });
      return;
    }
    if (photoUrl != null && typeof photoUrl !== "string") {
      response.status(400).json({ error: "photoUrl must be a string" });
      return;
    }

    response.json(
      matchmaking.enqueuePlayer({
        userId: userId.trim(),
        displayName: displayName.trim(),
        rankScore,
        photoUrl: typeof photoUrl === "string" ? photoUrl.trim() : null
      })
    );
  });

  app.delete("/ranked/queue/:ticketId", (request, response) => {
    const removed = matchmaking.cancelQueue(request.params.ticketId);
    response.json({ ok: removed });
  });

  app.get("/ranked/room/:roomId", (request, response) => {
    const room = matchmaking.getRoom(request.params.roomId);
    if (room == null) {
      response.status(404).json({ error: "Room not found" });
      return;
    }
    response.json(room);
  });

  app.post("/private-room", (request, response) => {
    const userId = request.body?.userId;
    const displayName = request.body?.displayName;
    const rankScore = request.body?.rankScore;
    const photoUrl = request.body?.photoUrl;
    if (typeof userId !== "string" || userId.trim().length === 0) {
      response.status(400).json({ error: "userId is required" });
      return;
    }
    if (typeof displayName !== "string" || displayName.trim().length === 0) {
      response.status(400).json({ error: "displayName is required" });
      return;
    }
    if (typeof rankScore !== "number") {
      response.status(400).json({ error: "rankScore is required" });
      return;
    }
    if (photoUrl != null && typeof photoUrl !== "string") {
      response.status(400).json({ error: "photoUrl must be a string" });
      return;
    }

    const room = privateRooms.createRoom({
      userId: userId.trim(),
      displayName: displayName.trim(),
      rankScore,
      photoUrl: typeof photoUrl === "string" ? photoUrl.trim() : null,
    });
    console.log(
      `[private_room] create code=${room.code} host=${room.hostUserId} seats=${room.seats.length} status=${room.status}`
    );
    response.json(room);
  });

  app.post("/private-room/join", (request, response) => {
    const code = request.body?.code;
    const userId = request.body?.userId;
    const displayName = request.body?.displayName;
    const rankScore = request.body?.rankScore;
    const photoUrl = request.body?.photoUrl;
    if (typeof code !== "string" || code.trim().length === 0) {
      response.status(400).json({ error: "code is required" });
      return;
    }
    if (typeof userId !== "string" || userId.trim().length === 0) {
      response.status(400).json({ error: "userId is required" });
      return;
    }
    if (typeof displayName !== "string" || displayName.trim().length === 0) {
      response.status(400).json({ error: "displayName is required" });
      return;
    }
    if (typeof rankScore !== "number") {
      response.status(400).json({ error: "rankScore is required" });
      return;
    }
    if (photoUrl != null && typeof photoUrl !== "string") {
      response.status(400).json({ error: "photoUrl must be a string" });
      return;
    }

    try {
      const room = privateRooms.joinRoom(code, {
        userId: userId.trim(),
        displayName: displayName.trim(),
        rankScore,
        photoUrl: typeof photoUrl === "string" ? photoUrl.trim() : null,
      });
      console.log(
        `[private_room] join code=${room.code} user=${userId.trim()} seats=${room.seats.length} status=${room.status}`
      );
      response.json(room);
    } catch (error) {
      response.status(400).json({
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  });

  app.post("/private-room/start", (request, response) => {
    const code = request.body?.code;
    const userId = request.body?.userId;
    if (typeof code !== "string" || code.trim().length === 0) {
      response.status(400).json({ error: "code is required" });
      return;
    }
    if (typeof userId !== "string" || userId.trim().length === 0) {
      response.status(400).json({ error: "userId is required" });
      return;
    }

    try {
      const room = privateRooms.startRoom(code, userId.trim());
      console.log(
        `[private_room] start code=${room.code} host=${userId.trim()} seats=${room.seats.length} status=${room.status}`
      );
      response.json(room);
    } catch (error) {
      response.status(400).json({
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  });

  app.get("/private-room/:code", (request, response) => {
    const room = privateRooms.getRoom(request.params.code);
    if (room == null) {
      console.log(
        `[private_room] get code=${request.params.code.trim().toUpperCase()} not_found`
      );
      response.status(404).json({ error: "Room not found" });
      return;
    }
    console.log(
      `[private_room] get code=${room.code} seats=${room.seats.length} status=${room.status}`
    );
    response.json(room);
  });

  return app;
}
