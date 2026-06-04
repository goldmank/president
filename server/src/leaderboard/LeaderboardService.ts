import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
  type App,
} from "firebase-admin/app";
import {
  getFirestore,
  type DocumentData,
  type Firestore,
} from "firebase-admin/firestore";
import type {
  LeaderboardEntry,
  LeaderboardReportPayload,
  LeaderboardSnapshot,
  LeaderboardUserProgress,
  LeaderboardWindow,
} from "@president/shared";

interface LeaderboardProfileDocument {
  userId: string;
  displayName: string;
  displayNameLower: string;
  photoUrl: string | null;
  gamesPlayed: number;
  presidentGames: number;
  viceGames: number;
  citizenGames: number;
  viceScumGames: number;
  scumGames: number;
  score: number;
  createdAt: number;
  updatedAt: number;
}

interface LeaderboardWindowEntryDocument {
  userId: string;
  displayName: string;
  displayNameLower: string;
  photoUrl: string | null;
  gamesPlayed: number;
  score: number;
  createdAt: number;
  updatedAt: number;
}

const PROFILE_COLLECTION = "leaderboardProfiles";
const REPORT_COLLECTION = "leaderboardReports";
const DAILY_COLLECTION = "leaderboardDaily";
const WEEKLY_COLLECTION = "leaderboardWeekly";
const DEFAULT_LIMIT = 50;

export class LeaderboardService {
  private static readonly defaultServiceAccountCandidates: string[] = [
    resolve(process.cwd(), "firebase-admin.json"),
    resolve(process.cwd(), "server/firebase-admin.json"),
  ];

  private app: App | null = null;
  private firestore: Firestore | null = null;
  private enabled = false;
  private loggedDisabledReason = false;

  public constructor() {
    this.initialize();
  }

  public async getUserProgress(userId: string): Promise<LeaderboardUserProgress> {
    const normalizedUserId = userId.trim();
    if (normalizedUserId.length === 0) {
      throw new Error("userId is required");
    }

    if (!this.enabled || this.firestore == null) {
      return this.emptyProgress(normalizedUserId);
    }

    const snapshot = await this.firestore
      .collection(PROFILE_COLLECTION)
      .doc(normalizedUserId)
      .get();

    return snapshot.exists
      ? this.profileDocumentToProgress(snapshot.data(), normalizedUserId)
      : this.emptyProgress(normalizedUserId);
  }

  public async getLeaderboard(
    window: LeaderboardWindow,
    viewerUserId?: string | null,
    limit?: number,
  ): Promise<LeaderboardSnapshot> {
    const requestedLimit =
      typeof limit === "number" && Number.isFinite(limit) ? limit : DEFAULT_LIMIT;
    const normalizedLimit = Math.max(
      1,
      Math.min(DEFAULT_LIMIT, Math.round(requestedLimit)),
    );
    const normalizedViewerUserId = viewerUserId?.trim() || null;

    if (!this.enabled || this.firestore == null) {
      return {
        window,
        limit: normalizedLimit,
        generatedAt: Date.now(),
        entries: [],
        viewerEntry: null,
      };
    }

    const baseEntries = await this.fetchWindowEntries(window);
    const rankedEntries = baseEntries
      .sort((left, right) => this.compareEntries(left, right))
      .map((entry, index) => ({
        ...entry,
        position: index + 1,
      }));

    const viewerEntry = normalizedViewerUserId == null
      ? null
      : rankedEntries.find((entry) => entry.userId === normalizedViewerUserId) ?? null;

    return {
      window,
      limit: normalizedLimit,
      generatedAt: Date.now(),
      entries: rankedEntries.slice(0, normalizedLimit),
      viewerEntry: viewerEntry == null
        ? null
        : {
            ...viewerEntry,
            inTopResults: viewerEntry.position <= normalizedLimit,
          },
    };
  }

  public async reportGameResult(
    payload: LeaderboardReportPayload,
  ): Promise<LeaderboardUserProgress> {
    if (!this.enabled || this.firestore == null) {
      throw new Error("Leaderboard storage is not configured");
    }

    const resultId = payload.resultId.trim();
    const userId = payload.userId.trim();
    const displayName = normalizeDisplayName(payload.displayName);
    const photoUrl = normalizeOptionalString(payload.photoUrl);
    const role = normalizeRole(payload.role);

    if (resultId.length === 0) {
      throw new Error("resultId is required");
    }
    if (userId.length === 0) {
      throw new Error("userId is required");
    }

    const reportedAt = Date.now();
    const dayKey = dayKeyFor(reportedAt);
    const weekKey = weekKeyFor(reportedAt);
    const scoreDelta = scoreForRole(role);
    const reportRef = this.firestore.collection(REPORT_COLLECTION).doc(`${userId}__${resultId}`);
    const profileRef = this.firestore.collection(PROFILE_COLLECTION).doc(userId);
    const dailyRef = this.firestore
      .collection(DAILY_COLLECTION)
      .doc(dayKey)
      .collection("players")
      .doc(userId);
    const weeklyRef = this.firestore
      .collection(WEEKLY_COLLECTION)
      .doc(weekKey)
      .collection("players")
      .doc(userId);

    let progress = this.emptyProgress(userId, displayName, photoUrl);
    let duplicateReport = false;

    await this.firestore.runTransaction(async (transaction) => {
      const reportSnapshot = await transaction.get(reportRef);
      if (reportSnapshot.exists) {
        duplicateReport = true;
        return;
      }

      const profileSnapshot = await transaction.get(profileRef);
      const dailySnapshot = await transaction.get(dailyRef);
      const weeklySnapshot = await transaction.get(weeklyRef);

      const baseProgress = profileSnapshot.exists
        ? this.profileDocumentToProgress(profileSnapshot.data(), userId)
        : this.emptyProgress(userId, displayName, photoUrl);
      const nextProgress = applyRoleToProgress(baseProgress, role, displayName, photoUrl, reportedAt);
      const profileCreatedAt = profileSnapshot.exists
        ? readNumber(profileSnapshot.data()?.createdAt) || reportedAt
        : reportedAt;

      const baseDailyEntry = dailySnapshot.exists
        ? this.windowDocumentToEntryDocument(dailySnapshot.data(), userId)
        : createEmptyWindowEntryDocument(userId, displayName, photoUrl, reportedAt);
      const nextDailyEntry = applyScoreToWindowEntry(
        baseDailyEntry,
        displayName,
        photoUrl,
        scoreDelta,
        reportedAt,
      );

      const baseWeeklyEntry = weeklySnapshot.exists
        ? this.windowDocumentToEntryDocument(weeklySnapshot.data(), userId)
        : createEmptyWindowEntryDocument(userId, displayName, photoUrl, reportedAt);
      const nextWeeklyEntry = applyScoreToWindowEntry(
        baseWeeklyEntry,
        displayName,
        photoUrl,
        scoreDelta,
        reportedAt,
      );

      transaction.set(
        profileRef,
        progressToProfileDocument(nextProgress, profileCreatedAt),
        { merge: true },
      );
      transaction.set(dailyRef, nextDailyEntry, { merge: true });
      transaction.set(weeklyRef, nextWeeklyEntry, { merge: true });
      transaction.set(reportRef, {
        resultId,
        userId,
        displayName,
        photoUrl,
        role,
        scoreDelta,
        dayKey,
        weekKey,
        createdAt: reportedAt,
      });

      progress = nextProgress;
    });

    return duplicateReport ? this.getUserProgress(userId) : progress;
  }

  private async fetchWindowEntries(window: LeaderboardWindow): Promise<LeaderboardEntry[]> {
    if (this.firestore == null) {
      return [];
    }

    if (window === "all_time") {
      const snapshot = await this.firestore.collection(PROFILE_COLLECTION).get();
      return snapshot.docs.map((doc) => {
        const progress = this.profileDocumentToProgress(doc.data(), doc.id);
        return {
          userId: progress.userId,
          displayName: progress.displayName,
          photoUrl: progress.photoUrl,
          score: progress.score,
          gamesPlayed: progress.gamesPlayed,
          position: 0,
        };
      });
    }

    const collection = window === "daily" ? DAILY_COLLECTION : WEEKLY_COLLECTION;
    const key = window === "daily" ? dayKeyFor(Date.now()) : weekKeyFor(Date.now());
    const snapshot = await this.firestore
      .collection(collection)
      .doc(key)
      .collection("players")
      .get();

    return snapshot.docs.map((doc) => {
      const entry = this.windowDocumentToEntryDocument(doc.data(), doc.id);
      return {
        userId: entry.userId,
        displayName: entry.displayName,
        photoUrl: entry.photoUrl,
        score: entry.score,
        gamesPlayed: entry.gamesPlayed,
        position: 0,
      };
    });
  }

  private compareEntries(left: LeaderboardEntry, right: LeaderboardEntry): number {
    if (left.score != right.score) {
      return right.score - left.score;
    }
    const nameCompare = left.displayName.localeCompare(right.displayName, undefined, {
      sensitivity: "base",
    });
    if (nameCompare !== 0) {
      return nameCompare;
    }
    return left.userId.localeCompare(right.userId);
  }

  private profileDocumentToProgress(
    data: DocumentData | undefined,
    userId: string,
  ): LeaderboardUserProgress {
    return {
      userId,
      displayName: normalizeDisplayName(readString(data?.displayName) ?? "Player"),
      photoUrl: normalizeOptionalString(readString(data?.photoUrl)),
      gamesPlayed: readNumber(data?.gamesPlayed),
      presidentGames: readNumber(data?.presidentGames),
      viceGames: readNumber(data?.viceGames),
      citizenGames: readNumber(data?.citizenGames),
      viceScumGames: readNumber(data?.viceScumGames),
      scumGames: readNumber(data?.scumGames),
      score: readNumber(data?.score),
      updatedAt: readNumber(data?.updatedAt),
    };
  }

  private windowDocumentToEntryDocument(
    data: DocumentData | undefined,
    userId: string,
  ): LeaderboardWindowEntryDocument {
    return {
      userId,
      displayName: normalizeDisplayName(readString(data?.displayName) ?? "Player"),
      displayNameLower: (readString(data?.displayNameLower) ?? "player").toLowerCase(),
      photoUrl: normalizeOptionalString(readString(data?.photoUrl)),
      gamesPlayed: readNumber(data?.gamesPlayed),
      score: readNumber(data?.score),
      createdAt: readNumber(data?.createdAt),
      updatedAt: readNumber(data?.updatedAt),
    };
  }

  private emptyProgress(
    userId: string,
    displayName = "Player",
    photoUrl: string | null = null,
  ): LeaderboardUserProgress {
    return {
      userId,
      displayName: normalizeDisplayName(displayName),
      photoUrl: normalizeOptionalString(photoUrl),
      gamesPlayed: 0,
      presidentGames: 0,
      viceGames: 0,
      citizenGames: 0,
      viceScumGames: 0,
      scumGames: 0,
      score: 0,
      updatedAt: 0,
    };
  }

  private initialize(): void {
    try {
      const existing = getApps()[0];
      if (existing) {
        this.app = existing;
        this.firestore = getFirestore(existing);
        this.enabled = true;
        console.log("[leaderboard] using existing firebase-admin app");
        return;
      }

      const serviceAccountPath = this.resolveServiceAccountPath();
      const projectId = this.readProjectId();

      if (serviceAccountPath && serviceAccountPath.trim().length > 0) {
        const absolutePath = resolve(serviceAccountPath);
        const serviceAccount = JSON.parse(readFileSync(absolutePath, "utf8"));
        this.app = initializeApp({
          credential: cert(serviceAccount),
          projectId,
        });
        this.firestore = getFirestore(this.app);
        this.enabled = true;
        console.log(
          `[leaderboard] initialized with service account path=${absolutePath} projectId=${projectId}`,
        );
        return;
      }

      if (process.env.FIREBASE_CONFIG || process.env.GOOGLE_CLOUD_PROJECT) {
        this.app = initializeApp({
          credential: applicationDefault(),
          projectId,
        });
        this.firestore = getFirestore(this.app);
        this.enabled = true;
        console.log(
          `[leaderboard] initialized with application default credentials projectId=${projectId}`,
        );
        return;
      }

      this.enabled = false;
      this.logDisabled("firebase-admin disabled: no leaderboard credentials configured");
    } catch (error) {
      this.enabled = false;
      console.log(
        `[leaderboard] init_error ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  private resolveServiceAccountPath(): string | null {
    const configuredPath = process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim();
    if (configuredPath != null && configuredPath.length > 0) {
      return configuredPath;
    }

    for (const finalPath of LeaderboardService.defaultServiceAccountCandidates) {
      if (existsSync(finalPath)) {
        return finalPath;
      }
    }

    return null;
  }

  private readProjectId(): string {
    try {
      const raw = readFileSync(resolve(process.cwd(), "app/firebase.json"), "utf8");
      const json = JSON.parse(raw) as {
        flutter?: {
          platforms?: { android?: { default?: { projectId?: string } } };
        };
      };
      return json.flutter?.platforms?.android?.default?.projectId ?? "president-bc5e7";
    } catch {
      return "president-bc5e7";
    }
  }

  private logDisabled(message: string): void {
    if (!this.loggedDisabledReason) {
      console.log(`[leaderboard] ${message}`);
      this.loggedDisabledReason = true;
    }
  }
}

function readNumber(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function readString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function normalizeDisplayName(value: string): string {
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : "Player";
}

function normalizeOptionalString(value: string | null | undefined): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeRole(value: string): string {
  const normalized = value.trim();
  switch (normalized) {
    case "President":
    case "Vice":
    case "Citizen":
    case "Vice Scum":
    case "Scum":
      return normalized;
    default:
      throw new Error(`Unsupported role: ${value}`);
  }
}

function scoreForRole(role: string): number {
  switch (role) {
    case "President":
      return 10;
    case "Vice":
      return 8;
    case "Citizen":
      return 5;
    case "Vice Scum":
      return 2;
    case "Scum":
      return 1;
    default:
      throw new Error(`Unsupported role: ${role}`);
  }
}

function applyRoleToProgress(
  progress: LeaderboardUserProgress,
  role: string,
  displayName: string,
  photoUrl: string | null,
  updatedAt: number,
): LeaderboardUserProgress {
  return {
    userId: progress.userId,
    displayName,
    photoUrl: photoUrl ?? progress.photoUrl,
    gamesPlayed: progress.gamesPlayed + 1,
    presidentGames: progress.presidentGames + (role === "President" ? 1 : 0),
    viceGames: progress.viceGames + (role === "Vice" ? 1 : 0),
    citizenGames: progress.citizenGames + (role === "Citizen" ? 1 : 0),
    viceScumGames: progress.viceScumGames + (role === "Vice Scum" ? 1 : 0),
    scumGames: progress.scumGames + (role === "Scum" ? 1 : 0),
    score: progress.score + scoreForRole(role),
    updatedAt,
  };
}

function progressToProfileDocument(
  progress: LeaderboardUserProgress,
  createdAt: number,
): LeaderboardProfileDocument {
  return {
    userId: progress.userId,
    displayName: progress.displayName,
    displayNameLower: progress.displayName.toLowerCase(),
    photoUrl: progress.photoUrl ?? null,
    gamesPlayed: progress.gamesPlayed,
    presidentGames: progress.presidentGames,
    viceGames: progress.viceGames,
    citizenGames: progress.citizenGames,
    viceScumGames: progress.viceScumGames,
    scumGames: progress.scumGames,
    score: progress.score,
    createdAt,
    updatedAt: progress.updatedAt,
  };
}

function createEmptyWindowEntryDocument(
  userId: string,
  displayName: string,
  photoUrl: string | null,
  timestamp: number,
): LeaderboardWindowEntryDocument {
  return {
    userId,
    displayName,
    displayNameLower: displayName.toLowerCase(),
    photoUrl,
    gamesPlayed: 0,
    score: 0,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

function applyScoreToWindowEntry(
  entry: LeaderboardWindowEntryDocument,
  displayName: string,
  photoUrl: string | null,
  scoreDelta: number,
  updatedAt: number,
): LeaderboardWindowEntryDocument {
  return {
    ...entry,
    displayName,
    displayNameLower: displayName.toLowerCase(),
    photoUrl: photoUrl ?? entry.photoUrl,
    gamesPlayed: entry.gamesPlayed + 1,
    score: entry.score + scoreDelta,
    updatedAt,
  };
}

function dayKeyFor(timestamp: number): string {
  return new Date(timestamp).toISOString().slice(0, 10);
}

function weekKeyFor(timestamp: number): string {
  const date = new Date(timestamp);
  const utcDate = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  const day = utcDate.getUTCDay() || 7;
  utcDate.setUTCDate(utcDate.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(utcDate.getUTCFullYear(), 0, 1));
  const weekNumber = Math.ceil((((utcDate.getTime() - yearStart.getTime()) / 86_400_000) + 1) / 7);
  return `${utcDate.getUTCFullYear()}-W${String(weekNumber).padStart(2, "0")}`;
}
