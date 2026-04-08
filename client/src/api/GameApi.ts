import type { GameAction, PublicGameState } from "@president/shared";

const baseUrl = import.meta.env.VITE_SERVER_URL ?? "http://localhost:3001";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${baseUrl}${path}`, {
    headers: {
      "Content-Type": "application/json"
    },
    ...init
  });

  if (!response.ok) {
    const payload = (await response.json().catch(() => null)) as { error?: string } | null;
    throw new Error(payload?.error ?? `Request failed with ${response.status}`);
  }

  return response.json() as Promise<T>;
}

export class GameApi {
  public async createGame(playerCount?: number): Promise<PublicGameState> {
    return request<PublicGameState>("/game", {
      method: "POST",
      body: JSON.stringify(playerCount ? { playerCount } : {})
    });
  }

  public async getGame(): Promise<PublicGameState> {
    return request<PublicGameState>("/game");
  }

  public async submitAction(action: GameAction): Promise<PublicGameState> {
    return request<PublicGameState>("/game/action", {
      method: "POST",
      body: JSON.stringify(action)
    });
  }

  public async stepBotTurn(): Promise<PublicGameState> {
    return request<PublicGameState>("/game/bot-turn", {
      method: "POST"
    });
  }
}
