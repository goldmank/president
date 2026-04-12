import type { GameAction, GameState, PublicGameState } from "@president/shared";
import {
  createGame,
  executeBotTurn,
  fastForwardToEnd,
  getPublicState,
  startNextRoundFromResults,
  submitAction,
} from "./presidentEngine.js";

export class GameManager {
  private state: GameState;

  public constructor() {
    this.state = createGame();
    this.logState("initialized");
  }

  public createNewGame(playerCount?: number): PublicGameState {
    this.state = createGame({ playerCount });
    console.log(`[game] createNewGame playerCount=${playerCount ?? "default"}`);
    this.logState("new_game");
    return getPublicState(this.state, "human-1");
  }

  public getState(): PublicGameState {
    this.logState("get_state");
    return getPublicState(this.state, "human-1");
  }

  public submit(action: GameAction): PublicGameState {
    console.log(`[game] submit action=${JSON.stringify(action)}`);
    submitAction(this.state, action);
    this.logState("after_submit");
    return getPublicState(this.state, "human-1");
  }

  public stepBotTurn(): PublicGameState {
    console.log(
      `[game] stepBotTurn currentTurn=${this.state.currentTurnPlayerId}`
    );
    executeBotTurn(this.state);
    this.logState("after_bot_turn");
    return getPublicState(this.state, "human-1");
  }

  public fastForward(): PublicGameState {
    console.log("[game] fastForward");
    fastForwardToEnd(this.state);
    this.logState("after_fast_forward");
    return getPublicState(this.state, "human-1");
  }

  public startNextRound(): PublicGameState {
    console.log("[game] startNextRound");
    startNextRoundFromResults(this.state);
    this.logState("after_start_next_round");
    return getPublicState(this.state, "human-1");
  }

  private logState(context: string): void {
    console.log(
      [
        `[game] ${context}`,
        `id=${this.state.id}`,
        `phase=${this.state.phase}`,
        `turn=${this.state.currentTurnPlayerId}`,
        `pile=${this.state.pile.currentSet?.cards.length ?? 0}`,
        `history=${this.state.pile.history.length}`,
        `players=${this.state.players
          .map(
            (player) =>
              `${player.id}:${player.hand.length}:${player.status}${
                player.finishingPosition ? `#${player.finishingPosition}` : ""
              }`
          )
          .join(",")}`
      ].join(" ")
    );
  }
}
