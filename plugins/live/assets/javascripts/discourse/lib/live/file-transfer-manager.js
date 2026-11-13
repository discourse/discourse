import { tracked } from "@glimmer/tracking";
import { manuallyTrack } from "discourse/lib/tracked-tools";

export const MAX_FILE_SIZE = 100 * 1024 * 1024;
export const CHUNK_SIZE = 16 * 1024;
export const MAX_RECEIVE_BYTES = 200 * 1024 * 1024;
const HIGH_WATER = 256 * 1024;
const ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const TERMINAL = new Set(["completed", "rejected", "cancelled", "failed"]);

// No signaling, URLs, downloads or execution: only explicitly accepted Blobs.
// Binary frames carry the transfer UUID, so delayed bytes from a cancelled
// transfer can never be appended to a subsequent file on the same channel.
export default class FileTransferManager {
  @tracked transfers = [];
  @tracked channelsRevision = 0;
  #peers = new Map();
  #active = new Map();
  #eligible;
  #timeout;

  constructor({ isEligible, timeoutMs = 120_000 }) {
    this.#eligible = isEligible;
    this.#timeout = timeoutMs;
  }

  attach(roomId, userId, channel) {
    this.disconnect(roomId, userId);
    const key = this.#key(roomId, userId);
    const peer = { roomId, userId, channel, key };
    this.#peers.set(key, peer);
    this.channelsRevision++;
    channel.onopen = () => this.channelsRevision++;
    channel.binaryType = "arraybuffer";
    channel.onmessage = ({ data }) => {
      try {
        if (!this.#eligible(roomId, userId)) {
          this.disconnect(roomId, userId);
          return;
        }
        this.#receive(peer, data);
      } catch {
        const transfer = this.#active.get(key);
        if (transfer) {
          this.#finish(transfer, "failed", "Invalid file transfer data");
          this.#control(peer, "cancel", transfer.entry.id);
        }
        this.disconnect(roomId, userId);
      }
    };
    channel.onclose = channel.onerror = () => this.disconnect(roomId, userId);
  }

  canSend(roomId, userId) {
    manuallyTrack(this.channelsRevision);
    manuallyTrack(this.transfers);
    const key = this.#key(roomId, userId);
    return !!(
      this.#eligible(roomId, userId) &&
      this.#peers.get(key)?.channel.readyState === "open" &&
      !this.#active.has(key) &&
      this.transfers.length < 100
    );
  }

  send(roomId, userId, file) {
    if (
      !this.canSend(roomId, userId) ||
      !(file instanceof Blob) ||
      !this.#validMetadata(file.name, file.size)
    ) {
      throw new Error("File transfer is unavailable or file is invalid");
    }
    const peer = this.#peers.get(this.#key(roomId, userId));
    const transfer = this.#create(
      peer,
      crypto.randomUUID(),
      file.name,
      file.size,
      "outgoing"
    );
    transfer.file = file;
    this.#control(peer, "offer", transfer.entry.id, {
      name: file.name,
      size: file.size,
    });
    return transfer.entry.id;
  }

  accept(id) {
    const t = this.#find(id);
    if (
      t?.entry.status !== "pending" ||
      !this.#eligible(t.peer.roomId, t.peer.userId)
    ) {
      return;
    }
    const retainedBytes = this.transfers.reduce(
      (sum, entry) =>
        sum +
        (entry.direction === "incoming" &&
        (entry.status === "transferring" || entry.status === "completed")
          ? entry.size
          : 0),
      0
    );
    if (retainedBytes + t.entry.size > MAX_RECEIVE_BYTES) {
      this.reject(id);
      return;
    }
    this.#update(t, { status: "transferring" });
    this.#arm(t);
    this.#control(t.peer, "accept", id);
  }

  reject(id) {
    const t = this.#find(id);
    if (t?.entry.status === "pending") {
      this.#control(t.peer, "reject", id);
      this.#finish(t, "rejected");
    }
  }

  cancel(id) {
    const t = this.#find(id);
    if (t) {
      this.#control(t.peer, "cancel", id);
      this.#finish(t, "cancelled");
    }
  }

  dismiss(id) {
    this.cancel(id);
    this.transfers = this.transfers.filter((entry) => entry.id !== id);
  }

  disconnect(roomId, userId) {
    const key = this.#key(roomId, userId);
    const peer = this.#peers.get(key);
    this.#peers.delete(key);
    const t = this.#active.get(key);
    if (t) {
      this.#finish(t, "failed", "Peer disconnected");
    }
    if (peer) {
      this.channelsRevision++;
      peer.channel.onopen = null;
      peer.channel.onmessage =
        peer.channel.onclose =
        peer.channel.onerror =
          null;
      peer.channel.close();
    }
  }

  leave(roomId) {
    for (const peer of this.#peers.values()) {
      if (peer.roomId === roomId) {
        this.disconnect(peer.roomId, peer.userId);
      }
    }
    this.transfers = this.transfers.filter((entry) => entry.roomId !== roomId);
  }

  destroy() {
    for (const peer of this.#peers.values()) {
      this.disconnect(peer.roomId, peer.userId);
    }
    this.transfers = [];
  }

  #key(roomId, userId) {
    return `${roomId}:${userId}`;
  }

  #validMetadata(name, size) {
    return (
      typeof name === "string" &&
      name.length > 0 &&
      name.length <= 255 &&
      name !== "." &&
      name !== ".." &&
      !/[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069/\\]/.test(name) &&
      Number.isSafeInteger(size) &&
      size >= 0 &&
      size <= MAX_FILE_SIZE
    );
  }

  #create(peer, id, name, size, direction) {
    const entry = {
      id,
      roomId: peer.roomId,
      userId: peer.userId,
      name,
      size,
      direction,
      status: direction === "incoming" ? "pending" : "waiting",
      progress: 0,
      blob: null,
      error: null,
    };
    const t = { peer, entry, offset: 0, chunks: [], timer: null };
    this.#active.set(peer.key, t);
    this.transfers = [...this.transfers, entry];
    this.#arm(t);
    return t;
  }

  #find(id) {
    return [...this.#active.values()].find((t) => t.entry.id === id);
  }

  #update(t, changes) {
    t.entry = { ...t.entry, ...changes };
    this.transfers = this.transfers.map((entry) =>
      entry.id === t.entry.id ? t.entry : entry
    );
  }

  #arm(t) {
    clearTimeout(t.timer);
    t.timer = setTimeout(() => {
      this.#control(t.peer, "cancel", t.entry.id);
      this.#finish(t, "failed", "File transfer timed out");
    }, this.#timeout);
  }

  #finish(t, status, error = null) {
    clearTimeout(t.timer);
    this.#active.delete(t.peer.key);
    t.file = null;
    t.chunks = [];
    this.#update(t, {
      status,
      error,
      ...(status === "completed" ? {} : { blob: null }),
    });
  }

  #control(peer, type, id, metadata = {}) {
    try {
      // Bound responses too: a remote offer flood must not grow our SCTP queue.
      if (peer.channel.bufferedAmount > HIGH_WATER * 2) {
        throw new Error("Control channel is congested");
      }
      peer.channel.send(JSON.stringify({ type, id, ...metadata }));
      return true;
    } catch {
      const t = this.#active.get(peer.key);
      if (t) {
        this.#finish(t, "failed", "Data channel unavailable");
      }
      this.disconnect(peer.roomId, peer.userId);
      return false;
    }
  }

  #receive(peer, data) {
    const t = this.#active.get(peer.key);
    if (typeof data !== "string") {
      if (
        !(data instanceof ArrayBuffer) ||
        data.byteLength <= 36 ||
        data.byteLength > CHUNK_SIZE + 36
      ) {
        throw new Error("Invalid frame");
      }
      const id = new TextDecoder().decode(new Uint8Array(data, 0, 36));
      if (!t || t.entry.id !== id) {
        return; // Unrequested or stale bytes are never retained.
      }
      if (t.entry.status !== "transferring") {
        throw new Error("Bytes before acceptance");
      }
      const chunk = data.slice(36);
      if (
        t.entry.direction !== "incoming" ||
        t.entry.status !== "transferring" ||
        chunk.byteLength !== Math.min(CHUNK_SIZE, t.entry.size - t.offset)
      ) {
        throw new Error("Unexpected bytes");
      }
      t.chunks.push(chunk);
      t.offset += chunk.byteLength;
      this.#update(t, { progress: t.offset / t.entry.size });
      this.#arm(t);
      return;
    }
    if (data.length > 2048) {
      throw new Error("Oversized control");
    }
    const message = JSON.parse(data);
    if (
      !message ||
      typeof message.id !== "string" ||
      !ID_PATTERN.test(message.id) ||
      typeof message.type !== "string"
    ) {
      throw new Error("Invalid control");
    }
    const { type, id, name, size } = message;
    if (type === "offer") {
      const incomingCount = [...this.#active.values()].filter(
        (transfer) => transfer.entry.direction === "incoming"
      ).length;
      if (
        t ||
        incomingCount >= 4 ||
        this.transfers.length >= 100 ||
        this.transfers.some((entry) => entry.id === id) ||
        !this.#validMetadata(name, size)
      ) {
        this.#control(peer, "reject", id);
        return;
      }
      this.#create(peer, id, name, size, "incoming");
      return;
    }
    if (!t || t.entry.id !== id) {
      return;
    }
    if (type === "cancel") {
      this.#finish(t, "cancelled");
    } else if (type === "reject" && t.entry.status === "waiting") {
      this.#finish(t, "rejected");
    } else if (
      type === "accept" &&
      t.entry.direction === "outgoing" &&
      t.entry.status === "waiting"
    ) {
      this.#update(t, { status: "transferring" });
      this.#arm(t);
      this.#pump(t);
    } else if (type === "complete" && t.entry.status === "transferring") {
      if (
        t.offset !== t.entry.size ||
        (t.entry.direction === "outgoing" && !t.sentComplete)
      ) {
        throw new Error("Incomplete file");
      }
      if (t.entry.direction === "incoming") {
        this.#update(t, {
          blob: new Blob(t.chunks, { type: "application/octet-stream" }),
          progress: 1,
        });
        if (!this.#control(peer, "complete", id)) {
          return;
        }
      }
      this.#update(t, { progress: 1 });
      this.#finish(t, "completed");
    } else {
      throw new Error("Unexpected control");
    }
  }

  async #pump(t) {
    try {
      while (this.#active.get(t.peer.key) === t && t.offset < t.entry.size) {
        if (!this.#eligible(t.peer.roomId, t.peer.userId)) {
          this.cancel(t.entry.id);
          return;
        }
        if (t.peer.channel.bufferedAmount > HIGH_WATER) {
          await new Promise((resolve) => setTimeout(resolve, 25));
          continue;
        }
        const bytes = await t.file
          .slice(t.offset, t.offset + CHUNK_SIZE)
          .arrayBuffer();
        if (this.#active.get(t.peer.key) !== t) {
          return;
        }
        if (!this.#eligible(t.peer.roomId, t.peer.userId)) {
          this.cancel(t.entry.id);
          return;
        }
        const frame = new Uint8Array(36 + bytes.byteLength);
        frame.set(new TextEncoder().encode(t.entry.id));
        frame.set(new Uint8Array(bytes), 36);
        t.peer.channel.send(frame.buffer);
        t.offset += bytes.byteLength;
        this.#update(t, { progress: t.offset / t.entry.size });
        this.#arm(t);
      }
      if (this.#active.get(t.peer.key) === t) {
        t.sentComplete = true;
        t.file = null;
        this.#control(t.peer, "complete", t.entry.id);
      }
    } catch {
      if (!TERMINAL.has(t.entry.status)) {
        this.#control(t.peer, "cancel", t.entry.id);
        this.#finish(t, "failed", "Could not send file");
      }
    }
  }
}
