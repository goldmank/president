import type { PublicGameState } from "@president/shared";

declare global {
  interface Window {
    render_game_to_text?: () => string;
    advanceTime?: (ms: number) => void;
  }
}

export function installDebugHooks(getState: () => PublicGameState | null, refresh: () => void): void {
  window.render_game_to_text = () => {
    const state = getState();

    if (!state) {
      return JSON.stringify({ ready: false });
    }

    return JSON.stringify({
      ready: true,
      coordinateSystem: "origin at top-left, +x right, +y down",
      phase: state.phase,
      currentTurnPlayerId: state.currentTurnPlayerId,
      requirementText: state.requirementText,
      pile: state.pile.currentSet
        ? {
            by: state.pile.currentSet.byPlayerName,
            rank: state.pile.currentSet.rank,
            count: state.pile.currentSet.count,
            cards: state.pile.currentSet.cards.map((card) => card.id)
          }
        : null,
      viewerHand: state.viewerHand.map((card) => card.id),
      players: state.players.map((player) => ({
        id: player.id,
        name: player.name,
        handCount: player.handCount,
        status: player.status,
        isCurrentTurn: player.isCurrentTurn
      })),
      logTail: state.log.slice(-5).map((entry) => entry.text)
    });
  };

  window.advanceTime = () => {
    refresh();
  };
}
