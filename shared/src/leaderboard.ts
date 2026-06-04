export type LeaderboardWindow = "all_time" | "weekly" | "daily";

export interface LeaderboardEntry {
  userId: string;
  displayName: string;
  photoUrl?: string | null;
  score: number;
  gamesPlayed: number;
  position: number;
}

export interface LeaderboardStanding extends LeaderboardEntry {
  inTopResults: boolean;
}

export interface LeaderboardSnapshot {
  window: LeaderboardWindow;
  limit: number;
  generatedAt: number;
  entries: LeaderboardEntry[];
  viewerEntry: LeaderboardStanding | null;
}

export interface LeaderboardUserProgress {
  userId: string;
  displayName: string;
  photoUrl?: string | null;
  gamesPlayed: number;
  presidentGames: number;
  viceGames: number;
  citizenGames: number;
  viceScumGames: number;
  scumGames: number;
  score: number;
  updatedAt: number;
}

export interface LeaderboardReportPayload {
  resultId: string;
  userId: string;
  displayName: string;
  photoUrl?: string | null;
  role: string;
}
