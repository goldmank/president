import {
  cardLabel,
  compareCards,
  createDeck,
  defaultRulesConfig,
  isThreeOfClubs,
  rankLabelMap,
  type Card,
  type GameAction,
  type GameState,
  type LogEntry,
  type MoveValidationResult,
  type ExchangePreview,
  type PlayedSet,
  type PlayerState,
  type PublicGameState,
  type RankValue,
  type RulesConfig
} from "@president/shared";
import { now, shuffle, sortHand } from "./random.js";

const botColors = ["#f97316", "#22c55e", "#a855f7", "#06b6d4", "#ef4444", "#f59e0b"];

export interface MoveOption {
  cardIds: string[];
  rank: RankValue;
  count: number;
}

export interface CreateGameOptions {
  playerCount?: number;
  humanName?: string;
  botPrefix?: string;
  rules?: Partial<RulesConfig>;
}

function buildLogEntry(text: string): LogEntry {
  return {
    id: `${now()}-${Math.random().toString(36).slice(2, 8)}`,
    text,
    timestamp: now()
  };
}

function addLog(state: GameState, text: string): void {
  state.log = [...state.log.slice(-19), buildLogEntry(text)];
}

function createPlayers(playerCount: number, humanName: string, botPrefix: string): PlayerState[] {
  const players: PlayerState[] = [
    {
      id: "human-1",
      name: humanName,
      kind: "human",
      avatarColor: "#3b82f6",
      hand: [],
      status: "active"
    }
  ];

  for (let index = 1; index < playerCount; index += 1) {
    players.push({
      id: `bot-${index}`,
      name: `${botPrefix} ${index}`,
      kind: "bot",
      avatarColor: botColors[(index - 1) % botColors.length],
      hand: [],
      status: "active"
    });
  }

  return players;
}

function dealCards(players: PlayerState[], rules: RulesConfig): void {
  const deck = shuffle(createDeck(rules.doubleDeck ? 2 : 1));

  deck.forEach((card, index) => {
    players[index % players.length].hand.push(card);
  });

  players.forEach((player) => {
    player.hand = sortHand(player.hand);
  });
}

function pickExtremeCards(hand: Card[], count: number, takeBest: boolean): Card[] {
  const ordered = sortHand(hand);
  if (count <= 0) {
    return [];
  }

  return takeBest ? ordered.slice(-count) : ordered.slice(0, count);
}

function findStartingPlayerId(players: PlayerState[]): string {
  const owner = players.find((player) => player.hand.some(isThreeOfClubs));

  return owner?.id ?? players[0].id;
}

function getPlayer(state: GameState, playerId: string): PlayerState {
  const player = state.players.find((candidate) => candidate.id === playerId);

  if (!player) {
    throw new Error(`Unknown player ${playerId}`);
  }

  return player;
}

function roleForFinishingPosition(
  finishingPosition: number | undefined,
  playerCount: number
): string | undefined {
  if (finishingPosition === 1) {
    return "President";
  }
  if (finishingPosition === 2) {
    return "Vice";
  }
  if (finishingPosition === playerCount - 1) {
    return "Vice Scum";
  }
  if (finishingPosition === playerCount) {
    return "Scum";
  }
  if (finishingPosition != null) {
    return "Citizen";
  }
  return undefined;
}

function getActivePlayers(state: GameState): PlayerState[] {
  return state.players.filter((player) => player.status !== "finished");
}

function getNextActivePlayerId(state: GameState, currentPlayerId: string): string {
  const currentIndex = state.players.findIndex((player) => player.id === currentPlayerId);

  for (let offset = 1; offset <= state.players.length; offset += 1) {
    const nextPlayer = state.players[(currentIndex + offset) % state.players.length];

    if (nextPlayer.status !== "finished") {
      return nextPlayer.id;
    }
  }

  return currentPlayerId;
}

function resolveRoundLeaderId(state: GameState, preferredLeaderId: string | null): string {
  if (!preferredLeaderId) {
    return getNextActivePlayerId(state, state.currentTurnPlayerId);
  }

  const preferred = getPlayer(state, preferredLeaderId);
  if (preferred.status !== "finished") {
    return preferredLeaderId;
  }

  return getNextActivePlayerId(state, preferredLeaderId);
}

function startNewRound(state: GameState, leaderId: string): void {
  state.pile.currentSet = null;
  state.pile.history = [];
  state.players.forEach((player) => {
    if (player.status === "passed") {
      player.status = "active";
    }
  });
  state.currentTurnPlayerId = leaderId;
  state.roundActionCount = 0;
  state.roundExpectedActions = getActivePlayers(state).length;
  addLog(state, `Round cleared. ${getPlayer(state, leaderId).name} leads next`);
  state.updatedAt = now();
}

function completeRoundIfNeeded(state: GameState, fallbackLeaderId: string): boolean {
  if (state.roundActionCount < state.roundExpectedActions) {
    return false;
  }

  const leaderId = resolveRoundLeaderId(state, state.lastSuccessfulPlayerId ?? fallbackLeaderId);
  startNewRound(state, leaderId);
  return true;
}

function setPlayerFinished(state: GameState, player: PlayerState): void {
  if (player.status === "finished") {
    return;
  }

  const finishedCount = state.players.filter((candidate) => candidate.status === "finished").length;
  player.status = "finished";
  player.finishingPosition = finishedCount + 1;
  addLog(state, `${player.name} finished in place ${player.finishingPosition}`);
}

function finalizeIfNeeded(state: GameState): void {
  const activePlayers = getActivePlayers(state);

  if (activePlayers.length <= 1) {
    if (activePlayers.length === 1) {
      setPlayerFinished(state, activePlayers[0]);
    }

    state.phase = "finished";
    state.currentTurnPlayerId = activePlayers[0]?.id ?? state.players[0].id;
  }
}

function removeCardsFromHand(hand: Card[], cardIds: string[]): Card[] {
  const remaining = hand.filter((card) => !cardIds.includes(card.id));
  return sortHand(remaining);
}

function buildPlayedSet(player: PlayerState, cards: Card[]): PlayedSet {
  return {
    cards: [...cards].sort(compareCards),
    rank: cards[0].rank,
    count: cards.length,
    byPlayerId: player.id,
    byPlayerName: player.name,
    timestamp: now()
  };
}

function groupPlayableSets(hand: Card[]): MoveOption[] {
  const byRank = new Map<RankValue, Card[]>();

  for (const card of hand) {
    const bucket = byRank.get(card.rank) ?? [];
    bucket.push(card);
    byRank.set(card.rank, bucket);
  }

  const moves: MoveOption[] = [];

  for (const [rank, cards] of byRank.entries()) {
    const sorted = [...cards].sort(compareCards);

    for (let count = 1; count <= sorted.length; count += 1) {
      moves.push({
        rank,
        count,
        cardIds: sorted.slice(0, count).map((card) => card.id)
      });
    }
  }

  return moves.sort((left, right) => {
    if (left.rank !== right.rank) {
      return left.rank - right.rank;
    }

    return left.count - right.count;
  });
}

export function requirementText(state: GameState): string {
  const currentSet = state.pile.currentSet;

  if (!currentSet) {
    return "New Round";
  }

  const setLabel = ["single", "pair", "triple", "four of a kind"][currentSet.count - 1] ?? `${currentSet.count}-card set`;
  return `Must play ${setLabel} higher than ${rankLabelMap[currentSet.rank]}`;
}

export function createGame(options: CreateGameOptions = {}): GameState {
  const rules: RulesConfig = {
    ...defaultRulesConfig,
    ...options.rules
  };
  const playerCount = Math.min(Math.max(options.playerCount ?? 4, rules.minPlayers), rules.maxPlayers);
  const players = createPlayers(playerCount, options.humanName ?? "You", options.botPrefix ?? "Bot");
  dealCards(players, rules);
  players.forEach((player) => {
    player.currentRole = "Citizen";
  });
  const createdAt = now();
  const state: GameState = {
    id: Math.random().toString(36).slice(2, 10),
    phase: "playing",
    rules,
    players,
    currentTurnPlayerId: findStartingPlayerId(players),
    lastSuccessfulPlayerId: null,
    roundActionCount: 0,
    roundExpectedActions: players.length,
    pile: {
      currentSet: null,
      history: []
    },
    log: [],
    createdAt,
    updatedAt: createdAt
  };

  addLog(state, `Round started. ${getPlayer(state, state.currentTurnPlayerId).name} leads first`);
  return state;
}

function clonePlayersForNextRound(state: GameState): PlayerState[] {
  const playerCount = state.players.length;
  return state.players.map((player) => ({
    id: player.id,
    name: player.name,
    kind: player.kind,
    avatarColor: player.avatarColor,
    hand: [],
    status: "active",
    currentRole: roleForFinishingPosition(player.finishingPosition, playerCount)
  }));
}

function planExchangeBetweenPlayers(
  left: PlayerState,
  right: PlayerState,
  leftSendCount: number,
  leftSendsBest: boolean,
  rightSendCount: number,
  rightSendsBest: boolean
): { leftSent: Card[]; rightSent: Card[] } {
  const leftSent = pickExtremeCards(left.hand, leftSendCount, leftSendsBest);
  const rightSent = pickExtremeCards(right.hand, rightSendCount, rightSendsBest);

  left.hand = sortHand([
    ...left.hand.filter((card) => !leftSent.some((sent) => sent.id === card.id)),
    ...rightSent
  ]);
  right.hand = sortHand([
    ...right.hand.filter((card) => !rightSent.some((sent) => sent.id === card.id)),
    ...leftSent
  ]);

  return { leftSent, rightSent };
}

function logPendingExchangePreview(
  label: string,
  fromPlayer: PlayerState,
  toPlayer: PlayerState,
  sentCards: Card[],
  receivedCards: Card[]
): void {
  console.log(
    [
      `[exchange_preview] ${label}`,
      `viewer=${fromPlayer.id}`,
      `to=${toPlayer.id}`,
      `send=${sentCards.map(cardLabel).join(",") || "-"}`,
      `receive=${receivedCards.map(cardLabel).join(",") || "-"}`
    ].join(" ")
  );
}

function preparePendingNextRound(state: GameState): void {
  if (state.pendingNextRoundPlayers && state.pendingExchangePreviews) {
    return;
  }

  const pendingPlayers = clonePlayersForNextRound(state);
  const previews: Record<string, ExchangePreview> = {};
  dealCards(pendingPlayers, state.rules);

  const president = pendingPlayers.find((player) => player.currentRole === "President");
  const vice = pendingPlayers.find((player) => player.currentRole === "Vice");
  const viceScum = pendingPlayers.find((player) => player.currentRole === "Vice Scum");
  const scum = pendingPlayers.find((player) => player.currentRole === "Scum");

  if (president && scum) {
    const exchange = planExchangeBetweenPlayers(president, scum, 2, false, 2, true);
    previews[president.id] = {
      viewerPlayerId: president.id,
      counterpartPlayerId: scum.id,
      sendCards: exchange.leftSent,
      receiveCards: exchange.rightSent
    };
    previews[scum.id] = {
      viewerPlayerId: scum.id,
      counterpartPlayerId: president.id,
      sendCards: exchange.rightSent,
      receiveCards: exchange.leftSent
    };
    logPendingExchangePreview("president-scum", president, scum, exchange.leftSent, exchange.rightSent);
    logPendingExchangePreview("president-scum", scum, president, exchange.rightSent, exchange.leftSent);
  }

  if (vice && viceScum && vice.id !== viceScum.id) {
    const exchange = planExchangeBetweenPlayers(vice, viceScum, 1, false, 1, true);
    previews[vice.id] = {
      viewerPlayerId: vice.id,
      counterpartPlayerId: viceScum.id,
      sendCards: exchange.leftSent,
      receiveCards: exchange.rightSent
    };
    previews[viceScum.id] = {
      viewerPlayerId: viceScum.id,
      counterpartPlayerId: vice.id,
      sendCards: exchange.rightSent,
      receiveCards: exchange.leftSent
    };
    logPendingExchangePreview("vice-vice-scum", vice, viceScum, exchange.leftSent, exchange.rightSent);
    logPendingExchangePreview("vice-vice-scum", viceScum, vice, exchange.rightSent, exchange.leftSent);
  }

  state.pendingNextRoundPlayers = pendingPlayers;
  state.pendingExchangePreviews = previews;
}

export function getExchangePreview(state: GameState, viewerPlayerId: string): ExchangePreview | null {
  if (state.phase !== "finished") {
    throw new Error("Exchange preview is only available after a round is finished");
  }

  preparePendingNextRound(state);
  return state.pendingExchangePreviews?.[viewerPlayerId] ?? null;
}

export function startNextRoundFromResults(state: GameState): GameState {
  if (state.phase !== "finished") {
    throw new Error("Cannot start next round before the current round is finished");
  }

  preparePendingNextRound(state);
  const playerCount = state.players.length;
  const president = state.players.find((player) => player.finishingPosition === 1);
  const vice = state.players.find((player) => player.finishingPosition === 2);
  const viceScum = state.players.find((player) => player.finishingPosition === playerCount - 1);
  const scum = state.players.find((player) => player.finishingPosition === playerCount);
  const pendingPlayers = state.pendingNextRoundPlayers ?? clonePlayersForNextRound(state);

  state.players = pendingPlayers.map((player) => ({
    id: player.id,
    name: player.name,
    kind: player.kind,
    avatarColor: player.avatarColor,
    hand: sortHand([...player.hand]),
    status: "active",
    currentRole: player.currentRole
  }));

  if (president && scum) {
    addLog(
      state,
      `${president.name} exchanged 2 lowest cards with ${scum.name}'s 2 highest cards`
    );
  }

  if (vice && viceScum && vice.id !== viceScum.id) {
    addLog(
      state,
      `${vice.name} exchanged 1 lowest card with ${viceScum.name}'s highest card`
    );
  }

  state.phase = "playing";
  state.lastSuccessfulPlayerId = null;
  state.pile.currentSet = null;
  state.pile.history = [];
  state.roundActionCount = 0;
  state.roundExpectedActions = state.players.length;
  state.currentTurnPlayerId = findStartingPlayerId(state.players);
  state.pendingNextRoundPlayers = undefined;
  state.pendingExchangePreviews = undefined;
  state.updatedAt = now();
  addLog(
    state,
    `Round started. ${getPlayer(state, state.currentTurnPlayerId).name} leads first`
  );

  return state;
}

export function getPublicState(state: GameState, viewerPlayerId: string): PublicGameState {
  const viewer = getPlayer(state, viewerPlayerId);

  return {
    id: state.id,
    phase: state.phase,
    rules: state.rules,
    players: state.players.map((player) => ({
      id: player.id,
      name: player.name,
      kind: player.kind,
      avatarColor: player.avatarColor,
      handCount: player.hand.length,
      status: player.status,
      finishingPosition: player.finishingPosition,
      currentRole: player.currentRole,
      isCurrentTurn: state.currentTurnPlayerId === player.id
    })),
    viewerPlayerId: viewer.id,
    viewerHand: sortHand(viewer.hand),
    currentTurnPlayerId: state.currentTurnPlayerId,
    lastSuccessfulPlayerId: state.lastSuccessfulPlayerId,
    pile: state.pile,
    requirementText: requirementText(state),
    log: state.log
  };
}

export function validateMove(state: GameState, playerId: string, cardIds: string[]): MoveValidationResult {
  if (state.phase !== "playing") {
    return { valid: false, reason: "Game is already finished" };
  }

  if (state.currentTurnPlayerId !== playerId) {
    return { valid: false, reason: "It is not your turn" };
  }

  if (cardIds.length < 1 || cardIds.length > 4) {
    return { valid: false, reason: "Choose between 1 and 4 cards" };
  }

  const player = getPlayer(state, playerId);
  const cards = cardIds.map((cardId) => player.hand.find((card) => card.id === cardId)).filter(Boolean) as Card[];

  if (cards.length !== cardIds.length) {
    return { valid: false, reason: "One or more selected cards are not in your hand" };
  }

  const firstRank = cards[0].rank;
  const sameRank = cards.every((card) => card.rank === firstRank);

  if (!sameRank) {
    return { valid: false, reason: "All played cards must share the same rank" };
  }

  const currentSet = state.pile.currentSet;

  if (!currentSet) {
    return { valid: true };
  }

  if (cards.length !== currentSet.count) {
    return { valid: false, reason: `You must play exactly ${currentSet.count} cards` };
  }

  if (firstRank <= currentSet.rank) {
    return { valid: false, reason: "Play must be higher than the current pile" };
  }

  return { valid: true };
}

function applyPlay(state: GameState, playerId: string, cardIds: string[]): void {
  const player = getPlayer(state, playerId);
  const cards = sortHand(player.hand.filter((card) => cardIds.includes(card.id)));
  const playedSet = buildPlayedSet(player, cards);
  player.hand = removeCardsFromHand(player.hand, cardIds);
  player.status = "active";
  state.pile.currentSet = playedSet;
  state.pile.history = [...state.pile.history, playedSet].slice(-12);
  state.lastSuccessfulPlayerId = player.id;
  state.updatedAt = now();

  const cardsText = cards.map(cardLabel).join(" ");
  addLog(state, `${player.name} played ${cardsText}`);
  state.roundActionCount += 1;

  if (player.hand.length === 0) {
    setPlayerFinished(state, player);
  }

  finalizeIfNeeded(state);

  if (state.phase === "finished") {
    return;
  }

  if (completeRoundIfNeeded(state, player.id)) {
    return;
  }

  state.currentTurnPlayerId = getNextActivePlayerId(state, player.id);
}

function applyPass(state: GameState, playerId: string): void {
  const player = getPlayer(state, playerId);
  if (!state.pile.currentSet) {
    addLog(state, `${player.name} passed`);
    state.roundActionCount += 1;
    if (!completeRoundIfNeeded(state, player.id)) {
      state.currentTurnPlayerId = getNextActivePlayerId(state, player.id);
      state.updatedAt = now();
    }
    return;
  }

  player.status = "passed";
  addLog(state, `${player.name} passed`);
  state.roundActionCount += 1;
  if (completeRoundIfNeeded(state, player.id)) {
    return;
  }

  state.currentTurnPlayerId = getNextActivePlayerId(state, player.id);
  state.updatedAt = now();
}

export function listValidMoves(state: GameState, playerId: string): MoveOption[] {
  const player = getPlayer(state, playerId);
  const candidates = groupPlayableSets(player.hand);
  const currentSet = state.pile.currentSet;

  return candidates.filter((move) => {
    if (!currentSet) {
      return true;
    }

    return move.count === currentSet.count && move.rank > currentSet.rank;
  });
}

export function submitAction(state: GameState, action: GameAction): GameState {
  if (action.type === "play") {
    const validation = validateMove(state, action.playerId, action.cardIds);

    if (!validation.valid) {
      throw new Error(validation.reason ?? "Invalid move");
    }

    applyPlay(state, action.playerId, action.cardIds);
  } else {
    if (state.currentTurnPlayerId !== action.playerId) {
      throw new Error("It is not your turn");
    }

    applyPass(state, action.playerId);
  }

  state.updatedAt = now();
  return state;
}

export function executeBotTurn(state: GameState): void {
  if (state.phase !== "playing") {
    return;
  }

  const player = getPlayer(state, state.currentTurnPlayerId);
  if (player.kind !== "bot") {
    return;
  }

  const validMoves = listValidMoves(state, player.id);

  if (validMoves.length > 0) {
    const selectedMove = validMoves[0];
    submitAction(state, {
      type: "play",
      playerId: player.id,
      cardIds: selectedMove.cardIds
    });
    return;
  }

  submitAction(state, {
    type: "pass",
    playerId: player.id
  });
}

export function executeAutoTurn(state: GameState): void {
  if (state.phase !== "playing") {
    return;
  }

  const player = getPlayer(state, state.currentTurnPlayerId);
  const validMoves = listValidMoves(state, player.id);

  if (validMoves.length > 0) {
    const selectedMove = validMoves[0];
    submitAction(state, {
      type: "play",
      playerId: player.id,
      cardIds: selectedMove.cardIds
    });
    return;
  }

  submitAction(state, {
    type: "pass",
    playerId: player.id
  });
}

export function fastForwardToEnd(state: GameState, maxSteps = 2048): void {
  let steps = 0;

  while (state.phase === "playing" && steps < maxSteps) {
    executeAutoTurn(state);
    steps += 1;
  }

  if (state.phase === "playing") {
    throw new Error("Fast forward exceeded step limit");
  }
}

export function runBotsUntilHumanTurn(state: GameState): GameState {
  let safety = 50;

  while (state.phase === "playing" && safety > 0) {
    const current = getPlayer(state, state.currentTurnPlayerId);
    if (current.kind === "human") {
      break;
    }

    executeBotTurn(state);
    safety -= 1;
  }

  return state;
}
