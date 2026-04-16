import type {
  RankedQueueStatusEvent,
  RankedQueueTicket,
  RankedRoomAssignedEvent,
  RankedRoomSeat,
  RankedRoomSnapshot,
  RankedSocketEvent
} from "@president/shared";

interface QueueEntry extends RankedQueueTicket {}

interface Subscriber {
  send(event: RankedSocketEvent): void;
}

interface EnqueuePlayerInput {
  userId: string;
  displayName: string;
  rankScore: number;
  photoUrl?: string | null;
}

const MIN_PLAYERS = 4;
const MAX_WAIT_MS = 30_000;

const botNames = [
  "Bot Atlas",
  "Bot Vance",
  "Bot Nova",
  "Bot Ember",
  "Bot Orion",
  "Bot Sable"
];

export class RankedMatchmakingService {
  private readonly queue = new Map<string, QueueEntry>();
  private readonly rooms = new Map<string, RankedRoomSnapshot>();
  private readonly subscribers = new Map<string, Set<Subscriber>>();
  private readonly intervalId: NodeJS.Timeout;

  public constructor() {
    this.intervalId = setInterval(() => {
      this.processQueue();
      this.broadcastQueueStatus();
    }, 1000);
  }

  public dispose(): void {
    clearInterval(this.intervalId);
  }

  public enqueuePlayer(input: EnqueuePlayerInput): RankedQueueTicket {
    for (const [ticketId, entry] of this.queue.entries()) {
      if (entry.userId === input.userId && entry.status === "queueing") {
        this.cancelQueue(ticketId, "Replaced by a new queue request");
      }
    }

    const now = Date.now();
    const ticket: QueueEntry = {
      ticketId: this.id("ticket"),
      userId: input.userId,
      displayName: input.displayName.trim() || "Player",
      rankScore: Math.max(0, Math.round(input.rankScore)),
      photoUrl: input.photoUrl?.trim() || null,
      queuedAt: now,
      maxWaitMs: MAX_WAIT_MS,
      status: "queueing"
    };

    this.queue.set(ticket.ticketId, ticket);
    this.processQueue();
    this.publishQueueStatus(ticket.ticketId);
    return ticket;
  }

  public cancelQueue(ticketId: string, reason = "Queue cancelled"): boolean {
    const entry = this.queue.get(ticketId);
    if (!entry) {
      return false;
    }
    entry.status = "cancelled";
    this.publish({
      type: "queue_cancelled",
      ticketId,
      reason
    });
    this.queue.delete(ticketId);
    this.subscribers.delete(ticketId);
    return true;
  }

  public getRoom(roomId: string): RankedRoomSnapshot | null {
    return this.rooms.get(roomId) ?? null;
  }

  public subscribe(ticketId: string, subscriber: Subscriber): () => void {
    const bucket = this.subscribers.get(ticketId) ?? new Set<Subscriber>();
    bucket.add(subscriber);
    this.subscribers.set(ticketId, bucket);

    const entry = this.queue.get(ticketId);
    if (!entry) {
      subscriber.send({
        type: "queue_cancelled",
        ticketId,
        reason: "Queue ticket not found"
      });
    } else if (entry.status === "assigned" && entry.roomId != null) {
      const room = this.rooms.get(entry.roomId);
      if (room) {
        subscriber.send({
          type: "room_assigned",
          ticketId,
          room
        });
      }
    } else {
      this.publishQueueStatus(ticketId);
    }

    return () => {
      const current = this.subscribers.get(ticketId);
      if (current == null) {
        return;
      }
      current.delete(subscriber);
      if (current.size === 0) {
        this.subscribers.delete(ticketId);
      }
    };
  }

  private processQueue(): void {
    const queued = [...this.queue.values()]
      .filter((entry) => entry.status === "queueing")
      .sort((left, right) => left.queuedAt - right.queuedAt);

    if (queued.length === 0) {
      return;
    }

    const now = Date.now();
    const anchor = queued[0];
    const matchedHumans = queued
      .filter((entry) => this.withinRankWindow(anchor, entry, now))
      .sort((left, right) => {
        const diff = Math.abs(left.rankScore - anchor.rankScore) -
            Math.abs(right.rankScore - anchor.rankScore);
        if (diff !== 0) {
          return diff;
        }
        return left.queuedAt - right.queuedAt;
      })
      .slice(0, MIN_PLAYERS);

    if (matchedHumans.length >= MIN_PLAYERS) {
      this.assignRoom(matchedHumans, false);
      return;
    }

    if (now - anchor.queuedAt >= MAX_WAIT_MS) {
      this.assignRoom(matchedHumans, true);
    }
  }

  private assignRoom(humanEntries: QueueEntry[], fillWithBots: boolean): void {
    if (humanEntries.length === 0) {
      return;
    }

    const now = Date.now();
    const roomId = this.id("room");
    const humanSeats = humanEntries.map<RankedRoomSeat>((entry) => ({
      playerId: entry.userId,
      displayName: entry.displayName,
      rankScore: entry.rankScore,
      photoUrl: entry.photoUrl?.trim() || null,
      isBot: false,
      connectionStatus: "connected"
    }));
    const botSeatIndexes = fillWithBots
      ? Array.from(
          { length: Math.max(0, MIN_PLAYERS - humanSeats.length) },
          (_value, index) => index
        )
      : [];
    const seats = [
      ...humanSeats,
      ...botSeatIndexes.map<RankedRoomSeat>((index) => ({
        playerId: `${roomId}-bot-${index + 1}`,
        displayName: botNames[index % botNames.length],
        rankScore: humanSeats.length === 0
          ? 0
          : humanSeats[index % humanSeats.length].rankScore,
        photoUrl: null,
        isBot: true,
        connectionStatus: "bot"
      }))
    ];

    const room: RankedRoomSnapshot = {
      roomId,
      status: "ready",
      seats,
      createdAt: now,
      startedAt: now,
      botFillApplied: fillWithBots
    };
    this.rooms.set(roomId, room);

    for (const entry of humanEntries) {
      entry.status = "assigned";
      entry.roomId = roomId;
      const event: RankedRoomAssignedEvent = {
        type: "room_assigned",
        ticketId: entry.ticketId,
        room
      };
      this.publishToTicket(entry.ticketId, event);
    }
  }

  private broadcastQueueStatus(): void {
    for (const entry of this.queue.values()) {
      if (entry.status === "queueing") {
        this.publishQueueStatus(entry.ticketId);
      }
    }
  }

  private publishQueueStatus(ticketId: string): void {
    const entry = this.queue.get(ticketId);
    if (!entry || entry.status !== "queueing") {
      return;
    }

    const event: RankedQueueStatusEvent = {
      type: "queue_status",
      ticketId,
      queuedPlayers: [...this.queue.values()].filter(
        (candidate) => candidate.status === "queueing"
      ).length,
      elapsedMs: Date.now() - entry.queuedAt,
      maxWaitMs: entry.maxWaitMs,
      rankWindow: this.rankWindowForWait(Date.now() - entry.queuedAt)
    };
    this.publishToTicket(ticketId, event);
  }

  private publish(event: RankedSocketEvent): void {
    if ("ticketId" in event) {
      this.publishToTicket(event.ticketId, event);
    }
  }

  private publishToTicket(ticketId: string, event: RankedSocketEvent): void {
    const bucket = this.subscribers.get(ticketId);
    if (bucket == null) {
      return;
    }
    for (const subscriber of bucket) {
      subscriber.send(event);
    }
  }

  private withinRankWindow(
    anchor: QueueEntry,
    candidate: QueueEntry,
    now: number
  ): boolean {
    if (anchor.ticketId === candidate.ticketId) {
      return true;
    }

    const anchorWindow = this.rankWindowForWait(now - anchor.queuedAt);
    const candidateWindow = this.rankWindowForWait(now - candidate.queuedAt);
    if (anchorWindow == null || candidateWindow == null) {
      return true;
    }
    return Math.abs(anchor.rankScore - candidate.rankScore) <=
      Math.max(anchorWindow, candidateWindow);
  }

  private rankWindowForWait(waitMs: number): number | null {
    if (waitMs < 5_000) {
      return 10;
    }
    if (waitMs < 10_000) {
      return 20;
    }
    if (waitMs < 20_000) {
      return 35;
    }
    if (waitMs < MAX_WAIT_MS) {
      return 60;
    }
    return null;
  }

  private id(prefix: string): string {
    return `${prefix}-${Math.random().toString(36).slice(2, 10)}`;
  }
}
