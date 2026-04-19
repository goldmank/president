import type {
  ExchangePreview,
  GameState,
  PrivateRoomSnapshot,
  PublicGameState,
} from "@president/shared";
import {
  createGame,
  getExchangePreview,
  getPublicState,
  runBotsUntilHumanTurn,
  startNextRoundFromResults,
  submitAction,
} from "../game/presidentEngine.js";

interface PrivateRoomGameSession {
  roomId: string;
  roomCode: string;
  state: GameState;
}

export class PrivateRoomGameService {
  private readonly sessions = new Map<string, PrivateRoomGameSession>();

  public getPublicState(
    room: PrivateRoomSnapshot,
    playerId: string,
  ): PublicGameState {
    const session = this.ensureSession(room, playerId);
    runBotsUntilHumanTurn(session.state);
    return getPublicState(session.state, playerId);
  }

  public submitPlayerAction(
    room: PrivateRoomSnapshot,
    playerId: string,
    action:
      | { type: "play"; cardIds: string[] }
      | { type: "pass" },
  ): PublicGameState {
    const session = this.ensureSession(room, playerId);
    if (action.type === "play") {
      submitAction(session.state, {
        type: "play",
        playerId,
        cardIds: action.cardIds,
      });
    } else {
      submitAction(session.state, {
        type: "pass",
        playerId,
      });
    }
    runBotsUntilHumanTurn(session.state);
    return getPublicState(session.state, playerId);
  }

  public getExchangePreview(
    room: PrivateRoomSnapshot,
    playerId: string,
  ): ExchangePreview | null {
    const session = this.ensureSession(room, playerId);
    return getExchangePreview(session.state, playerId);
  }

  public startNextRound(
    room: PrivateRoomSnapshot,
    playerId: string,
  ): PublicGameState {
    const session = this.ensureSession(room, playerId);
    startNextRoundFromResults(session.state);
    runBotsUntilHumanTurn(session.state);
    return getPublicState(session.state, playerId);
  }

  private ensureSession(
    room: PrivateRoomSnapshot,
    playerId: string,
  ): PrivateRoomGameSession {
    this.assertRoomReady(room);
    this.assertHumanPlayer(room, playerId);

    const existing = this.sessions.get(room.roomId);
    if (existing != null) {
      return existing;
    }

    const session: PrivateRoomGameSession = {
      roomId: room.roomId,
      roomCode: room.code,
      state: createGame({
        players: room.seats.map((seat) => ({
          id: seat.playerId,
          name: seat.displayName,
          kind: seat.isBot ? "bot" : "human",
        })),
      }),
    };
    runBotsUntilHumanTurn(session.state);
    this.sessions.set(room.roomId, session);
    console.log(
      `[private_room_game] create roomId=${room.roomId} code=${room.code} players=${room.seats.length} turn=${session.state.currentTurnPlayerId}`,
    );
    return session;
  }

  private assertRoomReady(room: PrivateRoomSnapshot): void {
    if (room.status !== "ready") {
      throw new Error("Match is not ready yet");
    }
  }

  private assertHumanPlayer(room: PrivateRoomSnapshot, playerId: string): void {
    const seat = room.seats.find((entry) => entry.playerId === playerId);
    if (seat == null || seat.isBot) {
      throw new Error("Player is not part of this room");
    }
  }
}
