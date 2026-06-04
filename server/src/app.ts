import express from "express";
import cors from "cors";
import { ErrorReportService } from "./error/ErrorReportService.js";
import { GameManager } from "./game/GameManager.js";
import { LeaderboardService } from "./leaderboard/LeaderboardService.js";
import { PrivateRoomGameService } from "./multiplayer/PrivateRoomGameService.js";
import { PrivateRoomService } from "./multiplayer/PrivateRoomService.js";
import { RankedMatchmakingService } from "./multiplayer/RankedMatchmakingService.js";

export function createApp(
  matchmaking: RankedMatchmakingService,
  privateRooms: PrivateRoomService
): express.Express {
  const app = express();
  const games = new GameManager();
  const errorReports = new ErrorReportService();
  const leaderboard = new LeaderboardService();
  const privateRoomGames = new PrivateRoomGameService();

  app.set("trust proxy", true);
  app.use(cors());
  app.use(express.json());
  app.use((request, response, next) => {
    const startedAt = Date.now();
    const body =
      request.method === "GET" || request.body == null
        ? ""
        : request.originalUrl === "/client-error-report"
          ? " body=[client-error-report]"
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

  app.get("/leaderboard", async (request, response) => {
    const window = parseLeaderboardWindow(request.query.window);
    if (window == null) {
      response.status(400).json({ error: "window must be all_time, weekly, or daily" });
      return;
    }

    const viewerUserId =
      typeof request.query.userId === "string" ? request.query.userId.trim() : null;
    const requestedLimit =
      typeof request.query.limit === "string" ? Number(request.query.limit) : undefined;

    try {
      response.json(await leaderboard.getLeaderboard(window, viewerUserId, requestedLimit));
    } catch (error) {
      console.error("[leaderboard] get_failed", error);
      response.status(500).json({ error: "Unable to load leaderboard" });
    }
  });

  app.get("/leaderboard/progress/:userId", async (request, response) => {
    const userId = request.params.userId?.trim();
    if (typeof userId !== "string" || userId.length === 0) {
      response.status(400).json({ error: "userId is required" });
      return;
    }

    try {
      response.json(await leaderboard.getUserProgress(userId));
    } catch (error) {
      console.error("[leaderboard] progress_failed", error);
      response.status(500).json({ error: "Unable to load player progress" });
    }
  });

  app.post("/leaderboard/report", async (request, response) => {
    const resultId = request.body?.resultId;
    const userId = request.body?.userId;
    const displayName = request.body?.displayName;
    const role = request.body?.role;
    const photoUrl = request.body?.photoUrl;

    if (typeof resultId !== "string" || resultId.trim().length === 0) {
      response.status(400).json({ error: "resultId is required" });
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
    if (typeof role !== "string" || role.trim().length === 0) {
      response.status(400).json({ error: "role is required" });
      return;
    }
    if (photoUrl != null && typeof photoUrl !== "string") {
      response.status(400).json({ error: "photoUrl must be a string" });
      return;
    }

    try {
      response.json(
        await leaderboard.reportGameResult({
          resultId: resultId.trim(),
          userId: userId.trim(),
          displayName: displayName.trim(),
          photoUrl: typeof photoUrl === "string" ? photoUrl.trim() : null,
          role: role.trim(),
        }),
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      const status = message.toLowerCase().includes("unsupported role") ? 400 : 500;
      if (status === 500) {
        console.error("[leaderboard] report_failed", error);
      }
      response.status(status).json({ error: message });
    }
  });

  app.post("/client-error-report", async (request, response) => {
    const payload = parseClientErrorReportPayload(request.body);
    if (payload == null) {
      response.status(400).json({ error: "Invalid error report payload" });
      return;
    }

    const sender = getSenderMetadata(request);

    try {
      const stored = await errorReports.storeReport(payload, sender);
      console.log(
        `[error_report] stored reportId=${stored.reportId} code=${payload.errorCode} ip=${sender.senderIp ?? "-"} user=${payload.user?.uid ?? "-"}`
      );
      response.status(201).json({ ok: true, reportId: stored.reportId });
    } catch (error) {
      console.error("[error_report] store_failed", error);
      response.status(500).json({ error: "Unable to store error report" });
    }
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

  app.get("/private-room/:code/game", (request, response) => {
    const playerId = request.query.playerId;
    if (typeof playerId !== "string" || playerId.trim().length === 0) {
      response.status(400).json({ error: "playerId is required" });
      return;
    }

    const room = privateRooms.getRoom(request.params.code);
    if (room == null) {
      response.status(404).json({ error: "Room not found" });
      return;
    }

    try {
      response.json(privateRoomGames.getPublicState(room, playerId.trim()));
    } catch (error) {
      response.status(400).json({
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  });

  app.post("/private-room/:code/game/action", (request, response) => {
    const playerId = request.body?.playerId;
    const type = request.body?.type;
    if (typeof playerId !== "string" || playerId.trim().length === 0) {
      response.status(400).json({ error: "playerId is required" });
      return;
    }
    if (type !== "play" && type !== "pass") {
      response.status(400).json({ error: "type must be play or pass" });
      return;
    }

    const room = privateRooms.getRoom(request.params.code);
    if (room == null) {
      response.status(404).json({ error: "Room not found" });
      return;
    }

    if (type === "play") {
      const cardIds = request.body?.cardIds;
      if (
        !Array.isArray(cardIds) ||
        !cardIds.every((entry) => typeof entry === "string")
      ) {
        response.status(400).json({ error: "cardIds must be a string array" });
        return;
      }

      try {
        response.json(
          privateRoomGames.submitPlayerAction(room, playerId.trim(), {
            type: "play",
            cardIds,
          }),
        );
      } catch (error) {
        response.status(400).json({
          error: error instanceof Error ? error.message : "Unknown error",
        });
      }
      return;
    }

    try {
      response.json(
        privateRoomGames.submitPlayerAction(room, playerId.trim(), {
          type: "pass",
        }),
      );
    } catch (error) {
      response.status(400).json({
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  });

  app.get("/private-room/:code/game/exchange-preview", (request, response) => {
    const playerId = request.query.playerId;
    if (typeof playerId !== "string" || playerId.trim().length === 0) {
      response.status(400).json({ error: "playerId is required" });
      return;
    }

    const room = privateRooms.getRoom(request.params.code);
    if (room == null) {
      response.status(404).json({ error: "Room not found" });
      return;
    }

    try {
      response.json(privateRoomGames.getExchangePreview(room, playerId.trim()));
    } catch (error) {
      response.status(400).json({
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  });

  app.post("/private-room/:code/game/next-round", (request, response) => {
    const playerId = request.body?.playerId;
    if (typeof playerId !== "string" || playerId.trim().length === 0) {
      response.status(400).json({ error: "playerId is required" });
      return;
    }

    const room = privateRooms.getRoom(request.params.code);
    if (room == null) {
      response.status(404).json({ error: "Room not found" });
      return;
    }

    try {
      response.json(privateRoomGames.startNextRound(room, playerId.trim()));
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

function parseClientErrorReportPayload(body: unknown) {
  if (!isRecord(body)) {
    return null;
  }

  const title = requiredString(body.title);
  const message = requiredString(body.message);
  const errorCode = typeof body.errorCode === "number" ? body.errorCode : null;
  if (title == null || message == null || errorCode == null || Number.isNaN(errorCode)) {
    return null;
  }

  return {
    title,
    errorCode,
    message,
    details: optionalString(body.details),
    reportContext: optionalString(body.reportContext),
    buildMode: optionalString(body.buildMode),
    serverEndpoint: optionalString(body.serverEndpoint),
    reportedAtUtc: optionalString(body.reportedAtUtc),
    user: parseClientErrorReportUser(body.user)
  };
}

function parseClientErrorReportUser(value: unknown) {
  if (value == null) {
    return null;
  }
  if (!isRecord(value)) {
    return null;
  }

  return {
    uid: optionalString(value.uid),
    displayName: optionalString(value.displayName),
    email: optionalString(value.email),
    photoUrl: optionalString(value.photoUrl)
  };
}

function getSenderMetadata(request: express.Request) {
  const forwardedForHeader = request.header("x-forwarded-for");
  const forwardedFor =
    typeof forwardedForHeader === "string"
      ? forwardedForHeader
          .split(",")
          .map((value) => value.trim())
          .filter((value) => value.length > 0)
      : [];

  return {
    senderIp: forwardedFor[0] ?? request.ip ?? request.socket.remoteAddress ?? null,
    forwardedFor,
    userAgent: optionalString(request.header("user-agent"))
  };
}

function requiredString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function optionalString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function parseLeaderboardWindow(value: unknown) {
  switch (value) {
    case "all_time":
    case "weekly":
    case "daily":
      return value;
    default:
      return null;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
