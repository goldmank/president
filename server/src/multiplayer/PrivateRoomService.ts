import type { PrivateRoomSnapshot, RankedRoomSeat } from "@president/shared";
import { FirestoreRoomPublisher } from "../firebase/FirestoreRoomPublisher.js";

interface PlayerInput {
  userId: string;
  displayName: string;
  rankScore: number;
  photoUrl?: string | null;
}

const MAX_PLAYERS = 8;
const READY_PLAYER_COUNT = 4;
const CODE_LENGTH = 6;
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const botNames = [
  "Bot Atlas",
  "Bot Vance",
  "Bot Nova",
  "Bot Ember",
  "Bot Orion",
  "Bot Sable"
];

export class PrivateRoomService {
  private readonly publisher = new FirestoreRoomPublisher();
  private readonly rooms = new Map<string, PrivateRoomSnapshot>();

  public createRoom(host: PlayerInput): PrivateRoomSnapshot {
    const roomId = this.id("room");
    const code = this.createCode();
    const room: PrivateRoomSnapshot = {
      roomId,
      code,
      hostUserId: host.userId,
      status: "waiting",
      seats: [this.humanSeat(host)],
      createdAt: Date.now(),
      maxPlayers: MAX_PLAYERS,
    };
    this.rooms.set(code, room);
    console.log(
      `[private_room_service] create code=${code} host=${host.userId} seats=${room.seats.length}`
    );
    void this.publisher.publishPrivateRoom(room);
    return room;
  }

  public joinRoom(code: string, player: PlayerInput): PrivateRoomSnapshot {
    const normalizedCode = code.trim().toUpperCase();
    const room = this.rooms.get(normalizedCode);
    if (room == null) {
      console.log(`[private_room_service] join code=${normalizedCode} user=${player.userId} result=not_found`);
      throw new Error("Room code not found");
    }

    const existingSeat = room.seats.find(
      (seat: RankedRoomSeat) => seat.playerId === player.userId
    );
    if (existingSeat != null) {
      console.log(
        `[private_room_service] join code=${normalizedCode} user=${player.userId} result=already_joined`
      );
      return room;
    }

    if (room.seats.length >= room.maxPlayers) {
      console.log(`[private_room_service] join code=${normalizedCode} user=${player.userId} result=full`);
      throw new Error("Room is full");
    }

    if (room.status === "ready") {
      console.log(`[private_room_service] join code=${normalizedCode} user=${player.userId} result=started`);
      throw new Error("Match already started");
    }

    room.seats = [...room.seats, this.humanSeat(player)];
    console.log(
      `[private_room_service] join code=${normalizedCode} user=${player.userId} seats=${room.seats.length} status=${room.status}`
    );
    void this.publisher.publishPrivateRoom(room);
    return room;
  }

  public startRoom(code: string, hostUserId: string): PrivateRoomSnapshot {
    const normalizedCode = code.trim().toUpperCase();
    const room = this.rooms.get(normalizedCode);
    if (room == null) {
      console.log(`[private_room_service] start code=${normalizedCode} host=${hostUserId} result=not_found`);
      throw new Error("Room code not found");
    }

    if (room.hostUserId !== hostUserId.trim()) {
      console.log(`[private_room_service] start code=${normalizedCode} host=${hostUserId} result=forbidden`);
      throw new Error("Only the host can start this room");
    }

    if (room.status === "ready") {
      console.log(
        `[private_room_service] start code=${normalizedCode} host=${hostUserId} result=already_started seats=${room.seats.length}`
      );
      return room;
    }

    const humanSeats = room.seats.filter((seat) => !seat.isBot);
    const missingSeats = Math.max(0, READY_PLAYER_COUNT - humanSeats.length);
    const botSeats = Array.from({ length: missingSeats }, (_value, index) =>
      this.botSeat(room.roomId, humanSeats, index)
    );

    room.seats = [...humanSeats, ...botSeats];
    room.status = "ready";
    console.log(
      `[private_room_service] start code=${normalizedCode} host=${hostUserId} seats=${room.seats.length} humans=${humanSeats.length} bots=${botSeats.length} status=${room.status}`
    );
    void this.publisher.publishPrivateRoom(room);
    return room;
  }

  public getRoom(code: string): PrivateRoomSnapshot | null {
    const normalizedCode = code.trim().toUpperCase();
    const room = this.rooms.get(normalizedCode) ?? null;
    console.log(
      `[private_room_service] get code=${normalizedCode} result=${room == null ? "not_found" : `ok seats=${room.seats.length} status=${room.status}`}`
    );
    return room;
  }

  private humanSeat(player: PlayerInput): RankedRoomSeat {
    return {
      playerId: player.userId,
      displayName: player.displayName.trim() || "Player",
      rankScore: Math.max(0, Math.round(player.rankScore)),
      photoUrl: player.photoUrl?.trim() || null,
      isBot: false,
      connectionStatus: "connected",
    };
  }

  private botSeat(
    roomId: string,
    humanSeats: RankedRoomSeat[],
    index: number
  ): RankedRoomSeat {
    return {
      playerId: `${roomId}-bot-${index + 1}`,
      displayName: botNames[index % botNames.length],
      rankScore: humanSeats.length === 0
        ? 0
        : humanSeats[index % humanSeats.length].rankScore,
      photoUrl: null,
      isBot: true,
      connectionStatus: "bot"
    };
  }

  private createCode(): string {
    while (true) {
      const code = Array.from({ length: CODE_LENGTH }, () => {
        const offset = Math.floor(Math.random() * CODE_ALPHABET.length);
        return CODE_ALPHABET[offset];
      }).join("");
      if (!this.rooms.has(code)) {
        return code;
      }
    }
  }

  private id(prefix: string): string {
    return `${prefix}-${Math.random().toString(36).slice(2, 10)}`;
  }
}
