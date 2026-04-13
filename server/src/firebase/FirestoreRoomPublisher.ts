import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { initializeApp, applicationDefault, cert, getApps, type App } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import type { PrivateRoomSnapshot } from "@president/shared";

export class FirestoreRoomPublisher {
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

  public async publishPrivateRoom(room: PrivateRoomSnapshot): Promise<void> {
    if (!this.enabled || this.firestore == null) {
      this.logDisabled(`skip publish roomId=${room.roomId} code=${room.code}`);
      return;
    }

    try {
      await this.firestore.collection("multiplayerRooms").doc(room.roomId).set(
        {
          ...room,
          roomType: "private",
          updatedAt: Date.now()
        },
        { merge: true }
      );
      console.log(
        `[firestore_room_publisher] published roomId=${room.roomId} code=${room.code} seats=${room.seats.length} status=${room.status}`
      );
    } catch (error) {
      console.log(
        `[firestore_room_publisher] publish_error roomId=${room.roomId} code=${room.code} error=${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private initialize(): void {
    try {
      const existing = getApps()[0];
      if (existing) {
        this.app = existing;
        this.firestore = getFirestore(existing);
        this.enabled = true;
        console.log("[firestore_room_publisher] using existing firebase-admin app");
        return;
      }

      const serviceAccountPath = this.resolveServiceAccountPath();
      const projectId = this.readProjectId();

      if (serviceAccountPath && serviceAccountPath.trim().length > 0) {
        const absolutePath = resolve(serviceAccountPath);
        const serviceAccount = JSON.parse(readFileSync(absolutePath, "utf8"));
        this.app = initializeApp({
          credential: cert(serviceAccount),
          projectId
        });
        this.firestore = getFirestore(this.app);
        this.enabled = true;
        console.log(
          `[firestore_room_publisher] initialized with service account path=${absolutePath} projectId=${projectId}`
        );
        return;
      }

      if (process.env.FIREBASE_CONFIG || process.env.GOOGLE_CLOUD_PROJECT) {
        this.app = initializeApp({
          credential: applicationDefault(),
          projectId
        });
        this.firestore = getFirestore(this.app);
        this.enabled = true;
        console.log(
          `[firestore_room_publisher] initialized with application default credentials projectId=${projectId}`
        );
        return;
      }

      this.enabled = false;
      this.logDisabled("firebase-admin disabled: no server credentials configured");
    } catch (error) {
      this.enabled = false;
      console.log(
        `[firestore_room_publisher] init_error ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private resolveServiceAccountPath(): string | null {
    const configuredPath = process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim();
    if (configuredPath != null && configuredPath.length > 0) {
      return configuredPath;
    }

    for (const finalPath of FirestoreRoomPublisher.defaultServiceAccountCandidates) {
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
      console.log(`[firestore_room_publisher] ${message}`);
      this.loggedDisabledReason = true;
    }
  }
}
