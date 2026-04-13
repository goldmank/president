import type { Card, RankValue } from "./card.js";
import type { RulesConfig } from "./rules.js";

export type PlayerStatus = "active" | "passed" | "finished";
export type PlayerKind = "human" | "bot";
export type GamePhase = "playing" | "finished";
export type ActionType = "play" | "pass";

export interface PlayerSummary {
  id: string;
  name: string;
  kind: PlayerKind;
  avatarColor: string;
}

export interface PlayerState extends PlayerSummary {
  hand: Card[];
  status: PlayerStatus;
  finishingPosition?: number;
  currentRole?: string;
}

export interface PlayedSet {
  cards: Card[];
  rank: RankValue;
  count: number;
  byPlayerId: string;
  byPlayerName: string;
  timestamp: number;
}

export interface PileState {
  currentSet: PlayedSet | null;
  history: PlayedSet[];
}

export interface LogEntry {
  id: string;
  text: string;
  timestamp: number;
}

export interface GameState {
  id: string;
  phase: GamePhase;
  rules: RulesConfig;
  players: PlayerState[];
  pendingNextRoundPlayers?: PlayerState[];
  pendingExchangePreviews?: Record<string, ExchangePreview>;
  currentTurnPlayerId: string;
  lastSuccessfulPlayerId: string | null;
  roundActionCount: number;
  roundExpectedActions: number;
  pile: PileState;
  log: LogEntry[];
  createdAt: number;
  updatedAt: number;
}

export interface PublicPlayerState extends PlayerSummary {
  handCount: number;
  status: PlayerStatus;
  finishingPosition?: number;
  currentRole?: string;
  isCurrentTurn: boolean;
}

export interface PublicGameState {
  id: string;
  phase: GamePhase;
  rules: RulesConfig;
  players: PublicPlayerState[];
  viewerPlayerId: string;
  viewerHand: Card[];
  currentTurnPlayerId: string;
  lastSuccessfulPlayerId: string | null;
  pile: PileState;
  requirementText: string;
  log: LogEntry[];
}

export interface ExchangePreview {
  viewerPlayerId: string;
  counterpartPlayerId: string;
  sendCards: Card[];
  receiveCards: Card[];
}

export interface PlayCardsAction {
  type: "play";
  playerId: string;
  cardIds: string[];
}

export interface PassAction {
  type: "pass";
  playerId: string;
}

export type GameAction = PlayCardsAction | PassAction;

export interface MoveValidationResult {
  valid: boolean;
  reason?: string;
}

export interface RankedPlayerResult {
  playerId: string;
  name: string;
  finishingPosition: number;
}
