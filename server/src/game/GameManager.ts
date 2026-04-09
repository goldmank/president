import type { GameAction, GameState, PublicGameState } from "@president/shared";
import { createGame, executeBotTurn, fastForwardToEnd, getPublicState, submitAction } from "./presidentEngine.js";

export class GameManager {
  private state: GameState;

  public constructor() {
    this.state = createGame();
  }

  public createNewGame(playerCount?: number): PublicGameState {
    this.state = createGame({ playerCount });
    return getPublicState(this.state, "human-1");
  }

  public getState(): PublicGameState {
    return getPublicState(this.state, "human-1");
  }

  public submit(action: GameAction): PublicGameState {
    submitAction(this.state, action);
    return getPublicState(this.state, "human-1");
  }

  public stepBotTurn(): PublicGameState {
    executeBotTurn(this.state);
    return getPublicState(this.state, "human-1");
  }

  public fastForward(): PublicGameState {
    fastForwardToEnd(this.state);
    return getPublicState(this.state, "human-1");
  }
}
