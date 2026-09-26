import http2 from "node:http2";
import jwt from "jsonwebtoken";
import { readFileSync } from "node:fs";

export interface LiveActivityContentState {
  status: string; // matches PantryOrderActivityAttributes.ContentState.status on the client
  etaText: string;
}

export interface PushProvider {
  /** ActivityKit update push — drives the Lock Screen / Dynamic Island. */
  sendLiveActivityUpdate(activityToken: string, state: LiveActivityContentState, staleInSeconds?: number): Promise<void>;
  sendLiveActivityEnd(activityToken: string, state: LiveActivityContentState): Promise<void>;
  /** Actionable notification — Approve/Reject buttons (canvas 4.1). */
  sendActionableNotification(
    deviceToken: string,
    opts: { title: string; body: string; categoryId: string; userInfo: Record<string, unknown> },
  ): Promise<void>;
}

function alertPayload(bundleId: string, opts: { title: string; body: string; categoryId: string; userInfo: Record<string, unknown> }) {
  return {
    aps: { alert: { title: opts.title, body: opts.body }, category: opts.categoryId, sound: "default" },
    ...opts.userInfo,
    _bundleId: bundleId,
  };
}

function liveActivityPayload(state: LiveActivityContentState, event: "update" | "end", staleInSeconds?: number) {
  return {
    aps: {
      timestamp: Math.floor(Date.now() / 1000),
      event,
      "content-state": state,
      ...(staleInSeconds ? { "stale-date": Math.floor(Date.now() / 1000) + staleInSeconds } : {}),
    },
  };
}

/** Logs the payload instead of calling Apple — used until real APNs credentials exist. */
class ConsolePushProvider implements PushProvider {
  async sendLiveActivityUpdate(token: string, state: LiveActivityContentState, staleInSeconds?: number) {
    console.log(`[apns:console] live-activity update -> ...${token.slice(-6)}`, liveActivityPayload(state, "update", staleInSeconds));
  }
  async sendLiveActivityEnd(token: string, state: LiveActivityContentState) {
    console.log(`[apns:console] live-activity end -> ...${token.slice(-6)}`, liveActivityPayload(state, "end"));
  }
  async sendActionableNotification(token: string, opts: Parameters<PushProvider["sendActionableNotification"]>[1]) {
    console.log(`[apns:console] actionable notification -> ...${token.slice(-6)}`, alertPayload("console", opts));
  }
}

/** Talks to Apple's real APNs HTTP/2 API using an ES256-signed provider token (.p8 key). */
class ApplePushProvider implements PushProvider {
  private readonly host: string;
  private readonly bundleId: string;
  private readonly teamId: string;
  private readonly keyId: string;
  private readonly privateKey: string;
  private cachedToken?: { value: string; issuedAt: number };

  constructor(opts: { teamId: string; keyId: string; keyPath: string; bundleId: string; sandbox: boolean }) {
    this.teamId = opts.teamId;
    this.keyId = opts.keyId;
    this.privateKey = readFileSync(opts.keyPath, "utf8");
    this.bundleId = opts.bundleId;
    this.host = opts.sandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  }

  private providerToken(): string {
    const now = Math.floor(Date.now() / 1000);
    if (this.cachedToken && now - this.cachedToken.issuedAt < 55 * 60) return this.cachedToken.value;
    const token = jwt.sign({ iss: this.teamId, iat: now }, this.privateKey, {
      algorithm: "ES256",
      keyid: this.keyId,
    });
    this.cachedToken = { value: token, issuedAt: now };
    return token;
  }

  private async post(deviceToken: string, pushType: "liveactivity" | "alert", payload: unknown, priority = 10): Promise<void> {
    return new Promise((resolve, reject) => {
      const client = http2.connect(`https://${this.host}`);
      client.on("error", reject);

      const req = client.request({
        ":method": "POST",
        ":path": `/3/device/${deviceToken}`,
        authorization: `bearer ${this.providerToken()}`,
        "apns-topic": pushType === "liveactivity" ? `${this.bundleId}.push-type.liveactivity` : this.bundleId,
        "apns-push-type": pushType,
        "apns-priority": String(priority),
      });

      let responseBody = "";
      req.setEncoding("utf8");
      req.on("data", (chunk) => (responseBody += chunk));
      req.on("response", (headers) => {
        const status = headers[":status"];
        req.on("end", () => {
          client.close();
          if (status && status >= 200 && status < 300) resolve();
          else reject(new Error(`APNs ${status}: ${responseBody}`));
        });
      });
      req.on("error", reject);
      req.end(JSON.stringify(payload));
    });
  }

  async sendLiveActivityUpdate(token: string, state: LiveActivityContentState, staleInSeconds?: number) {
    await this.post(token, "liveactivity", liveActivityPayload(state, "update", staleInSeconds));
  }
  async sendLiveActivityEnd(token: string, state: LiveActivityContentState) {
    await this.post(token, "liveactivity", liveActivityPayload(state, "end"));
  }
  async sendActionableNotification(token: string, opts: Parameters<PushProvider["sendActionableNotification"]>[1]) {
    await this.post(token, "alert", alertPayload(this.bundleId, opts));
  }
}

function buildProvider(): PushProvider {
  const { APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_PATH, APNS_BUNDLE_ID } = process.env;
  if (APNS_KEY_ID && APNS_TEAM_ID && APNS_KEY_PATH && APNS_BUNDLE_ID) {
    return new ApplePushProvider({
      teamId: APNS_TEAM_ID,
      keyId: APNS_KEY_ID,
      keyPath: APNS_KEY_PATH,
      bundleId: APNS_BUNDLE_ID,
      sandbox: process.env.NODE_ENV !== "production",
    });
  }
  console.warn("[apns] APNs credentials not fully configured — using the console push stub instead of real APNs");
  return new ConsolePushProvider();
}

export const pushProvider: PushProvider = buildProvider();
