import { tracked } from "@glimmer/tracking";
import { manuallyTrack } from "discourse/lib/tracked-tools";
import openReceiveSink from "./file-receive-sink.js";

export const MAX_FILE_SIZE = 100 * 1024 * 1024;
export const CHUNK_SIZE = 16 * 1024;
export const RECEIVE_WINDOW = 256 * 1024;
export const MAX_RECEIVE_BYTES = 200 * 1024 * 1024;
const HIGH_WATER = 256 * 1024;
const ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const TERMINAL = new Set(["completed", "rejected", "cancelled", "failed"]);

// No signaling, URLs, downloads or execution: only explicitly accepted disk files.
// Binary frames carry the transfer UUID, so delayed bytes from a cancelled
// transfer can never be appended to a subsequent file on the same channel.
export default class FileTransferManager {
  @tracked transfers = [];
  @tracked channelsRevision = 0;
  #peers = new Map();
  #active = new Map();
  #eligible;
  #timeout;
  #sendAllowed;
  #receiveAllowed;
  #openSink;
  #retained = new Map();
  #retiring = new Map();
  #sinkSizes = new WeakMap();

  constructor({
    isEligible,
    isSendAllowed = isEligible,
    isReceiveAllowed = isEligible,
    openReceiveSink: openSink = openReceiveSink,
    timeoutMs = 120_000,
  }) {
    this.#eligible = isEligible;
    this.#timeout = timeoutMs;
    this.#sendAllowed = isSendAllowed;
    this.#receiveAllowed = isReceiveAllowed;
    this.#openSink = openSink;
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
      this.#sendAllowed(roomId, userId) &&
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

  async accept(id) {
    const t = this.#find(id);
    if (
      t?.entry.status !== "pending" ||
      !this.#eligible(t.peer.roomId, t.peer.userId) ||
      !this.#receiveAllowed(t.peer.roomId, t.peer.userId)
    ) {
      return;
    }
    // Reservations include initialization and retained disk files, not RAM.
    const retainedBytes = this.transfers.reduce(
      (sum, entry) =>
        sum +
        (entry.direction === "incoming" &&
        ["initializing", "transferring", "completed"].includes(entry.status)
          ? entry.size
          : 0),
      0
    );
    const retiringBytes = [...this.#retiring.values()].reduce(
      (sum, size) => sum + size,
      0
    );
    if (retainedBytes + retiringBytes + t.entry.size > MAX_RECEIVE_BYTES) {
      this.reject(id);
      return;
    }
    this.#update(t, { status: "initializing" });
    try {
      const sink = await this.#openSink(t.entry.name);
      if (!this.#isActive(t)) {
        await sink.discard();
        return;
      }
      t.sink = sink;
      this.#sinkSizes.set(sink, t.entry.size);
      if (
        !this.#eligible(t.peer.roomId, t.peer.userId) ||
        !this.#receiveAllowed(t.peer.roomId, t.peer.userId)
      ) {
        this.cancel(id);
        return;
      }
      this.#update(t, { status: "transferring" });
      this.#arm(t);
      this.#control(t.peer, "accept", id);
    } catch {
      if (this.#isActive(t)) {
        this.#control(t.peer, "cancel", id);
        this.#finish(t, "failed", "storage_unavailable");
      }
    }
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
    this.#discard(this.#retained.get(id));
    this.#retained.delete(id);
    this.transfers = this.transfers.filter((entry) => entry.id !== id);
  }

  async getReceivedFile(id) {
    const entry = this.transfers.find((e) => e.id === id);
    const sink = this.#retained.get(id);
    if (!entry?.hasFile || entry.status !== "completed" || !sink) {
      throw new Error("Received file is unavailable");
    }
    const file = await sink.getFile();
    if (this.#retained.get(id) !== sink || !(file instanceof File)) {
      throw new Error("Received file is unavailable");
    }
    return file;
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
    for (const entry of this.transfers.filter((e) => e.roomId === roomId)) {
      this.#discard(this.#retained.get(entry.id));
      this.#retained.delete(entry.id);
    }
    this.transfers = this.transfers.filter((entry) => entry.roomId !== roomId);
  }

  destroy() {
    for (const peer of this.#peers.values()) {
      this.disconnect(peer.roomId, peer.userId);
    }
    for (const sink of this.#retained.values()) {
      this.#discard(sink);
    }
    this.#retained.clear();
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
      hasFile: false,
      error: null,
    };
    const t = {
      peer,
      entry,
      offset: 0,
      acknowledged: 0,
      received: 0,
      pendingBytes: 0,
      queue: [],
      busy: false,
      timer: null,
    };
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

  #isActive(t) {
    return this.#active.get(t.peer.key) === t;
  }

  #discard(sink) {
    // A cleanup failure must not resurrect an entry or cause an unhandled rejection.
    if (sink && !this.#retiring.has(sink)) {
      this.#retiring.set(sink, this.#sinkSizes.get(sink) || 0);
      Promise.resolve()
        .then(() => sink.discard())
        .then(() => this.#retiring.delete(sink))
        .catch(() => {
          // Failed deletion is not reclaimed disk space. Keep its reservation
          // until this manager is gone; stale orphan cleanup can retry later.
        });
    }
  }

  #finish(t, status, error = null) {
    if (!this.#isActive(t)) {
      return;
    }
    clearTimeout(t.timer);
    this.#active.delete(t.peer.key);
    t.file = null;
    t.queue = [];
    if (status === "completed" && t.sink) {
      this.#retained.set(t.entry.id, t.sink);
    } else {
      this.#discard(t.sink);
    }
    t.sink = null;
    this.#update(t, {
      status,
      error,
      ...(status === "completed" ? {} : { hasFile: false }),
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
      if (
        t.entry.direction !== "incoming" ||
        !this.#receiveAllowed(peer.roomId, peer.userId) ||
        t.busy ||
        t.pendingBytes + data.byteLength - 36 > RECEIVE_WINDOW ||
        data.byteLength - 36 !== Math.min(CHUNK_SIZE, t.entry.size - t.received)
      ) {
        throw new Error("Unexpected bytes or receive window exceeded");
      }
      // Explicit bounded queue, including the currently writing frame. Never
      // append peer-controlled chunks to an unbounded promise chain.
      const chunk = data.slice(36);
      t.received += chunk.byteLength;
      t.pendingBytes += chunk.byteLength;
      t.queue.push(chunk);
      this.#write(t);
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
        !this.#receiveAllowed(peer.roomId, peer.userId) ||
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
    } else if (
      type === "ack" &&
      t.entry.direction === "outgoing" &&
      t.entry.status === "transferring"
    ) {
      if (
        !Number.isSafeInteger(message.offset) ||
        message.offset > t.offset ||
        message.offset <= t.acknowledged ||
        (message.offset !== t.entry.size &&
          message.offset % CHUNK_SIZE !== 0) ||
        t.sentComplete
      ) {
        throw new Error("Invalid receive acknowledgement");
      }
      t.acknowledged = message.offset;
      this.#update(t, { progress: t.acknowledged / t.entry.size });
      this.#arm(t);
      this.#pump(t);
    } else if (type === "complete" && t.entry.status === "transferring") {
      if (
        t.offset !== t.entry.size ||
        t.busy ||
        t.pendingBytes !== 0 ||
        (t.entry.direction === "outgoing" && !t.sentComplete)
      ) {
        throw new Error("Incomplete file");
      }
      if (t.entry.direction === "incoming") {
        if (!this.#receiveAllowed(peer.roomId, peer.userId)) {
          throw new Error("Receive permission revoked");
        }
        t.busy = true;
        this.#completeReceive(t);
      } else {
        this.#update(t, { progress: 1 });
        this.#finish(t, "completed");
      }
    } else {
      throw new Error("Unexpected control");
    }
  }

  async #write(t) {
    if (t.writing) {
      return;
    }
    t.writing = true;
    try {
      while (this.#isActive(t) && t.queue.length) {
        const chunk = t.queue.shift();
        await t.sink.write(chunk);
        if (!this.#isActive(t)) {
          return;
        }
        if (
          !this.#eligible(t.peer.roomId, t.peer.userId) ||
          !this.#receiveAllowed(t.peer.roomId, t.peer.userId)
        ) {
          this.cancel(t.entry.id);
          return;
        }
        t.offset += chunk.byteLength;
        t.pendingBytes -= chunk.byteLength;
        this.#update(t, { progress: t.offset / t.entry.size });
        this.#arm(t);
        if (!this.#control(t.peer, "ack", t.entry.id, { offset: t.offset })) {
          return;
        }
      }
    } catch {
      this.#diskFailure(t);
    } finally {
      t.writing = false;
    }
  }

  async #completeReceive(t) {
    try {
      const metadata = await t.sink.finish();
      if (!this.#isActive(t)) {
        return;
      }
      if (
        !this.#eligible(t.peer.roomId, t.peer.userId) ||
        !this.#receiveAllowed(t.peer.roomId, t.peer.userId)
      ) {
        this.cancel(t.entry.id);
        return;
      }
      if (metadata?.size !== t.entry.size) {
        throw new Error("Disk file size mismatch");
      }
      if (!this.#control(t.peer, "complete", t.entry.id)) {
        return;
      }
      this.#update(t, { hasFile: true, progress: 1 });
      this.#finish(t, "completed");
    } catch {
      this.#diskFailure(t);
    }
  }

  #diskFailure(t) {
    if (this.#isActive(t)) {
      this.#control(t.peer, "cancel", t.entry.id);
      this.#finish(t, "failed", "storage_failed");
    }
  }

  async #pump(t) {
    if (t.pumping || t.sentComplete) {
      return;
    }
    t.pumping = true;
    try {
      while (this.#isActive(t)) {
        if (
          !this.#eligible(t.peer.roomId, t.peer.userId) ||
          !this.#sendAllowed(t.peer.roomId, t.peer.userId)
        ) {
          this.cancel(t.entry.id);
          return;
        }
        if (t.offset === t.entry.size && t.acknowledged === t.entry.size) {
          t.sentComplete = true;
          t.file = null;
          this.#control(t.peer, "complete", t.entry.id);
          return;
        }
        if (
          t.offset === t.entry.size ||
          t.offset - t.acknowledged >= RECEIVE_WINDOW
        ) {
          return;
        }
        if (t.peer.channel.bufferedAmount > HIGH_WATER) {
          await new Promise((resolve) => setTimeout(resolve, 25));
          continue;
        }
        const bytes = await t.file
          .slice(t.offset, t.offset + CHUNK_SIZE)
          .arrayBuffer();
        if (!this.#isActive(t)) {
          return;
        }
        if (
          !this.#eligible(t.peer.roomId, t.peer.userId) ||
          !this.#sendAllowed(t.peer.roomId, t.peer.userId)
        ) {
          this.cancel(t.entry.id);
          return;
        }
        const frame = new Uint8Array(36 + bytes.byteLength);
        frame.set(new TextEncoder().encode(t.entry.id));
        frame.set(new Uint8Array(bytes), 36);
        // Set the offset before sending: test transports may deliver immediately.
        t.offset += bytes.byteLength;
        t.peer.channel.send(frame.buffer);
        this.#arm(t);
        // Continue only while the bounded receive window has space.
      }
    } catch {
      if (!TERMINAL.has(t.entry.status)) {
        this.#control(t.peer, "cancel", t.entry.id);
        this.#finish(t, "failed", "Could not send file");
      }
    } finally {
      t.pumping = false;
    }
  }
}
