import { ajax } from "discourse/lib/ajax";

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

  constructor({ isActiveRoom, buildPayload, onExpelled }) {
    this.#isActiveRoom = isActiveRoom;
    this.#buildPayload = buildPayload;
    this.#onExpelled = onExpelled;
  }

  start(roomId) {
    if (this.#timers.has(roomId)) {
      return;
    }

    const timer = setInterval(() => this.#beat(roomId), HEARTBEAT_INTERVAL_MS);
    this.#timers.set(roomId, timer);
  }

  stop(roomId) {
    const timer = this.#timers.get(roomId);
    if (timer) {
      clearInterval(timer);
      this.#timers.delete(roomId);
      this.#inFlight.delete(roomId);
      // eslint-disable-next-line no-console
      console.log(`[voice] heartbeat stopped for room ${roomId}`);
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
      await ajax(`/voice/rooms/${roomId}/heartbeat`, {
        type: "POST",
        data: this.#buildPayload(roomId),
      });
      // eslint-disable-next-line no-console
      console.log(`[voice] heartbeat sent for room ${roomId}`);
    } catch (error) {
      const status = error?.jqXHR?.status || error?.status;
      // eslint-disable-next-line no-console
      console.warn(`[voice] heartbeat failed for room ${roomId}`, error);

      if (status === 403 || status === 404 || status === 410) {
        this.#onExpelled(roomId);
      }
    } finally {
      this.#inFlight.delete(roomId);
    }
  }
}
