import { ajax } from "discourse/lib/ajax";
import liveLog from "discourse/plugins/live/discourse/lib/live/logger";

const HEARTBEAT_INTERVAL_MS = 10000;

// Keeps per-room presence alive server-side. A heartbeat rejected with a
// membership-shaped status means the server no longer recognizes the
// session; onExpelled lets the caller unwind the call.
export default class HeartbeatManager {
  #timers = new Map();
  #inFlight = new Set();

  #isActiveRoom;
  #buildPayload;
  #onExpelled;
  #intervalMs;
  #timeoutMs;

  constructor({
    isActiveRoom,
    buildPayload,
    onExpelled,
    intervalMs = HEARTBEAT_INTERVAL_MS,
    timeoutMs = intervalMs,
  }) {
    this.#isActiveRoom = isActiveRoom;
    this.#buildPayload = buildPayload;
    this.#onExpelled = onExpelled;
    this.#intervalMs = intervalMs;
    this.#timeoutMs = timeoutMs;
  }

  start(roomId) {
    if (this.#timers.has(roomId)) {
      return;
    }

    const timer = setInterval(() => this.#beat(roomId), this.#intervalMs);
    this.#timers.set(roomId, timer);
  }

  stop(roomId) {
    const timer = this.#timers.get(roomId);
    if (timer) {
      clearInterval(timer);
      this.#timers.delete(roomId);
      this.#inFlight.delete(roomId);

      liveLog.info(`[live] heartbeat stopped for room ${roomId}`);
    }
  }

  stopAll() {
    for (const roomId of [...this.#timers.keys()]) {
      this.stop(roomId);
    }
  }

  async #beat(roomId) {
    if (!this.#isActiveRoom(roomId)) {
      this.stop(roomId);
      return;
    }

    if (this.#inFlight.has(roomId)) {
      return;
    }

    this.#inFlight.add(roomId);

    try {
      await ajax(`/live/rooms/${roomId}/heartbeat`, {
        type: "POST",
        data: this.#buildPayload(roomId),
        // A beat that never reaches the server (offline, connection reset,
        // stalled socket) must still settle: `ajax` leaves unsent requests
        // pending by default, which would hold the in-flight guard and
        // silence every later beat for the rest of the call.
        ignoreUnsent: false,
        timeout: this.#timeoutMs,
      });

      liveLog.info(`[live] heartbeat sent for room ${roomId}`);
    } catch (error) {
      const status = error?.jqXHR?.status || error?.status;

      liveLog.warn(`[live] heartbeat failed for room ${roomId}`);

      if (status === 403 || status === 404 || status === 410) {
        this.#onExpelled(roomId);
      }
    } finally {
      this.#inFlight.delete(roomId);
    }
  }
}
