export type RankedQueueStatus = "queueing" | "assigned" | "cancelled";
export type RankedRoomStatus = "searching" | "ready";
export type RankedSeatConnectionStatus = "connected" | "bot";
export type PrivateRoomStatus = "waiting" | "ready";

export interface RankedQueueTicket {
  ticketId: string;
  userId: string;
  displayName: string;
  rankScore: number;
  photoUrl?: string | null;
  queuedAt: number;
  maxWaitMs: number;
  status: RankedQueueStatus;
  roomId?: string;
}

export interface RankedRoomSeat {
  playerId: string;
  displayName: string;
  rankScore: number;
  photoUrl?: string | null;
  isBot: boolean;
  connectionStatus: RankedSeatConnectionStatus;
}

export interface RankedRoomSnapshot {
  roomId: string;
  status: RankedRoomStatus;
  seats: RankedRoomSeat[];
  createdAt: number;
  startedAt: number;
  botFillApplied: boolean;
}

export interface PrivateRoomSnapshot {
  roomId: string;
  code: string;
  hostUserId: string;
  status: PrivateRoomStatus;
  seats: RankedRoomSeat[];
  createdAt: number;
  maxPlayers: number;
}

export interface RankedQueueStatusEvent {
  type: "queue_status";
  ticketId: string;
  queuedPlayers: number;
  elapsedMs: number;
  maxWaitMs: number;
  rankWindow: number | null;
}

export interface RankedRoomAssignedEvent {
  type: "room_assigned";
  ticketId: string;
  room: RankedRoomSnapshot;
}

export interface RankedQueueCancelledEvent {
  type: "queue_cancelled";
  ticketId: string;
  reason: string;
}

export interface RankedSocketErrorEvent {
  type: "error";
  message: string;
}

export interface PrivateRoomUpdatedEvent {
  type: "private_room_updated";
  room: PrivateRoomSnapshot;
}

export interface PrivateRoomClosedEvent {
  type: "private_room_closed";
  code: string;
  reason: string;
}

export type RankedSocketEvent =
  | RankedQueueStatusEvent
  | RankedRoomAssignedEvent
  | RankedQueueCancelledEvent
  | RankedSocketErrorEvent;

export type PrivateRoomSocketEvent =
  | PrivateRoomUpdatedEvent
  | PrivateRoomClosedEvent
  | RankedSocketErrorEvent;
