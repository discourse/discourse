const PRESENCE_GRACE_MS = 15000;

// Peers engaged from an early offer before presence caught up. Each gets a
// grace window; when it expires without presence confirming the peer,
// onExpired lets the caller decide whether to tear the connection down.
export default class PresencePendingPeers {
  #keys = new Set();
  #timers = new Map();

  #onExpired;

  constructor({ onExpired }) {
    this.#onExpired = onExpired;
  }

  mark(roomId, userId) {
    const key = this.#key(roomId, userId);
    if (this.#keys.has(key)) {
      return;
    }

    this.#keys.add(key);

    const timer = setTimeout(() => {
      this.#timers.delete(key);
      this.#keys.delete(key);
      this.#onExpired(roomId, userId);
    }, PRESENCE_GRACE_MS);

    this.#timers.set(key, timer);
  }

  clear(roomId, userId) {
    const key = this.#key(roomId, userId);
    const timer = this.#timers.get(key);

    if (timer) {
      clearTimeout(timer);
      this.#timers.delete(key);
    }

    this.#keys.delete(key);
  }

  has(roomId, userId) {
    return this.#keys.has(this.#key(roomId, userId));
  }

  clearAll(roomId = null) {
    for (const [key, timer] of this.#timers) {
      if (roomId === null || key.startsWith(`${roomId}:`)) {
        clearTimeout(timer);
        this.#timers.delete(key);
        this.#keys.delete(key);
      }
    }
  }

  #key(roomId, userId) {
    return `${roomId}:${userId}`;
  }
}
