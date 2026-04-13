import { createServer } from "node:http";
import { WebSocketServer } from "ws";
import { createApp } from "./app.js";
import { PrivateRoomService } from "./multiplayer/PrivateRoomService.js";
import { RankedMatchmakingService } from "./multiplayer/RankedMatchmakingService.js";

const port = Number(process.env.PORT ?? 3001);
const host = process.env.HOST ?? "0.0.0.0";
const matchmaking = new RankedMatchmakingService();
const privateRooms = new PrivateRoomService();
const app = createApp(matchmaking, privateRooms);
const server = createServer(app);
const websocketServer = new WebSocketServer({ server, path: "/ranked/ws" });

websocketServer.on("connection", (socket, request) => {
  const url = new URL(request.url ?? "/ranked/ws", `http://${request.headers.host ?? "localhost"}`);
  const ticketId = url.searchParams.get("ticketId");
  console.log(`[ranked_ws] upgrade url=${url.toString()} ticketId=${ticketId ?? "-"}`);

  if (ticketId == null || ticketId.trim().length === 0) {
    socket.send(JSON.stringify({ type: "error", message: "ticketId is required" }));
    socket.close();
    return;
  }

  const unsubscribe = matchmaking.subscribe(ticketId, {
    send(event) {
      socket.send(JSON.stringify(event));
    }
  });

  socket.on("close", () => {
    console.log(`[ranked_ws] close ticketId=${ticketId}`);
    unsubscribe();
  });
});

server.listen(port, host, () => {
  console.log(`President server listening on http://${host}:${port}`);
});
