import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

export interface ClientErrorReportPayload {
  title: string;
  errorCode: number;
  message: string;
  details: string | null;
  reportContext: string | null;
  buildMode: string | null;
  serverEndpoint: string | null;
  reportedAtUtc: string | null;
  user: ClientErrorReportUserInfo | null;
}

export interface ClientErrorReportUserInfo {
  uid: string | null;
  displayName: string | null;
  email: string | null;
  photoUrl: string | null;
}

export interface ClientErrorReportRequestMeta {
  senderIp: string | null;
  forwardedFor: string[];
  userAgent: string | null;
}

interface StoredClientErrorReport {
  reportId: string;
  receivedAtUtc: string;
  sender: ClientErrorReportRequestMeta;
  report: ClientErrorReportPayload;
}

export class ErrorReportService {
  private readonly reportsDir = path.resolve(
    fileURLToPath(new URL(".", import.meta.url)),
    "..",
    "..",
    "error-reports"
  );

  async storeReport(
    payload: ClientErrorReportPayload,
    sender: ClientErrorReportRequestMeta
  ): Promise<{ reportId: string; filePath: string }> {
    await mkdir(this.reportsDir, { recursive: true });

    const reportId = randomUUID();
    const receivedAtUtc = new Date().toISOString();
    const report: StoredClientErrorReport = {
      reportId,
      receivedAtUtc,
      sender,
      report: payload
    };

    const fileName = this.buildFileName(receivedAtUtc, payload.errorCode, reportId);
    const filePath = path.join(this.reportsDir, fileName);

    await writeFile(filePath, `${JSON.stringify(report, null, 2)}\n`, "utf8");

    return { reportId, filePath };
  }

  private buildFileName(
    receivedAtUtc: string,
    errorCode: number,
    reportId: string
  ): string {
    const safeTimestamp = receivedAtUtc.replaceAll(":", "-").replaceAll(".", "-");
    return `${safeTimestamp}_${errorCode}_${reportId}.json`;
  }
}
