import { tracked } from "@glimmer/tracking";
import { manuallyTrack } from "discourse/lib/tracked-tools";
import openReceiveSink from "./file-receive-sink.js";
import {
  DEFAULT_MAX_FILE_SIZE,
  MAX_CONFIGURED_FILE_SIZE,
} from "./file-transfer-limits.js";

export const CHUNK_SIZE = 16 * 1024;
export const RECEIVE_WINDOW = 256 * 1024;
const HIGH_WATER = 256 * 1024;
const ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const TERMINAL = new Set(["completed", "rejected", "cancelled", "failed"]);
const MAX_ENTRIES = 100;
const ACK_INTERVAL = 64 * 1024;
const DISCARD_RETRY_DELAYS = [5_000, 30_000, 120_000];
export const OFFER_RATE_LIMIT = Object.freeze({
  perPeer: 5,
  total: 20,
  windowMs: 60_000,
});

export class FileTransferRateLimitError extends Error {}

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
  #getMaxFileSize;
  #estimateStorage;
  #retained = new Map();
  #retiring = new Map();
  #sinkSizes = new WeakMap();
  #offerLimit;
  #now;
  #incomingOffers = [];
  #outgoingOffers = [];

  constructor({
    isEligible,
    isSendAllowed = isEligible,
    isReceiveAllowed = isEligible,
    openReceiveSink: openSink = openReceiveSink,
    timeoutMs = 120_000,
    getMaxFileSize = () => DEFAULT_MAX_FILE_SIZE,
    estimateStorage = () => globalThis.navigator?.storage?.estimate?.(),
    offerLimit = OFFER_RATE_LIMIT,
    now = () => Date.now(),
  }) {
    this.#eligible = isEligible;
    this.#timeout = timeoutMs;
    this.#sendAllowed = isSendAllowed;
    this.#receiveAllowed = isReceiveAllowed;
    this.#openSink = openSink;
    this.#getMaxFileSize = getMaxFileSize;
    this.#estimateStorage = estimateStorage;
    this.#offerLimit = offerLimit;
    this.#now = now;
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
        // Roster updates can lag the data channel, so ineligibility ends the
        // transfer but keeps the channel: it can't be recreated without a new
        // peer connection.
        if (!this.#eligible(roomId, userId)) {
          this.#refuseIneligible(peer, data);
          return;
        }
        this.#receive(peer, data);
      } catch {
        const transfer = this.#active.get(key);
        if (transfer) {
          this.#finish(transfer, "failed", "invalid_data");
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
      this.#hasRoom()
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
    // Receivers enforce the same limit; checking here explains the refusal.
    if (!this.#withinOfferLimit(this.#outgoingOffers, userId)) {
      throw new FileTransferRateLimitError();
    }
    this.#outgoingOffers.push({ userId, at: this.#now() });
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
    if (!this.#validMetadata(t.entry.name, t.entry.size)) {
      this.reject(id);
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
    if (
      retainedBytes + retiringBytes + t.entry.size >
      2 * this.#maxFileSize()
    ) {
      this.#control(t.peer, "reject", id);
      this.#finish(t, "failed", "storage_budget_exceeded");
      return;
    }
    this.#update(t, { status: "initializing" });
    try {
      const enoughSpace = await this.#hasEstimatedReceiveSpace();
      if (!this.#isActive(t)) {
        return;
      }
      if (
        !this.#eligible(t.peer.roomId, t.peer.userId) ||
        !this.#receiveAllowed(t.peer.roomId, t.peer.userId) ||
        !this.#validMetadata(t.entry.name, t.entry.size)
      ) {
        this.cancel(id);
        return;
      }
      if (!enoughSpace) {
        this.#control(t.peer, "reject", id);
        this.#finish(t, "failed", "storage_insufficient");
        return;
      }
      const sink = await this.#openSink(t.entry.name);
      this.#sinkSizes.set(sink, t.entry.size);
      if (!this.#isActive(t)) {
        this.#discard(sink);
        return;
      }
      t.sink = sink;
      if (
        !this.#eligible(t.peer.roomId, t.peer.userId) ||
        !this.#receiveAllowed(t.peer.roomId, t.peer.userId) ||
        !this.#validMetadata(t.entry.name, t.entry.size)
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

  dismissFinished() {
    for (const entry of this.transfers) {
      if (TERMINAL.has(entry.status)) {
        this.dismiss(entry.id);
      }
    }
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
      this.#finish(t, "failed", "peer_disconnected");
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

  async #hasEstimatedReceiveSpace() {
    let estimate;
    try {
      estimate = await this.#estimateStorage();
    } catch {
      // Estimates are advisory. Missing/blocked APIs must not prevent OPFS
      // receives; write/close failures still fail safely and remove partials.
      return true;
    }
    const { quota, usage } = estimate || {};
    if (
      !Number.isFinite(quota) ||
      !Number.isFinite(usage) ||
      quota < 0 ||
      usage < 0
    ) {
      return true;
    }
    // Usage already includes persisted files and retiring downloads. Reserve
    // only unwritten bytes of accepted/initializing receives, including this
    // one, to avoid concurrently accepting more than the estimate can fit.
    let unwrittenBytes = 0;
    for (const t of this.#active.values()) {
      if (
        t.entry.direction === "incoming" &&
        ["initializing", "transferring"].includes(t.entry.status)
      ) {
        unwrittenBytes += t.entry.size - t.offset;
      }
    }
    return unwrittenBytes <= Math.max(0, quota - usage);
  }

  #refuseIneligible(peer, data) {
    const t = this.#active.get(peer.key);
    if (t) {
      this.#control(peer, "cancel", t.entry.id);
      this.#finish(t, "cancelled");
      return;
    }
    if (typeof data !== "string" || data.length > 2048) {
      return;
    }
    try {
      const { type, id } = JSON.parse(data) || {};
      if (type === "offer" && typeof id === "string" && ID_PATTERN.test(id)) {
        this.#control(peer, "reject", id);
      }
    } catch {
      // Nothing to answer.
    }
  }

  // Sliding window; refused offers aren't recorded so a flood can't grow it.
  #withinOfferLimit(log, userId) {
    const { perPeer, total, windowMs } = this.#offerLimit;
    const since = this.#now() - windowMs;
    while (log.length && log[0].at <= since) {
      log.shift();
    }
    const fromPeer = log.filter((offer) => offer.userId === userId).length;
    return fromPeer < perPeer && log.length < total;
  }

  // Finished entries without a retained file can be dropped to make room;
  // only pending, active and saveable entries count toward the cap.
  #evictable(entry) {
    return TERMINAL.has(entry.status) && !entry.hasFile;
  }

  #hasRoom() {
    return (
      this.transfers.filter((entry) => !this.#evictable(entry)).length <
      MAX_ENTRIES
    );
  }

  #key(roomId, userId) {
    return `${roomId}:${userId}`;
  }

  #maxFileSize() {
    const bytes = this.#getMaxFileSize();
    return Number.isSafeInteger(bytes) &&
      bytes > 0 &&
      bytes <= MAX_CONFIGURED_FILE_SIZE
      ? bytes
      : 0;
  }

  #validMetadata(name, size) {
    const maxSize = this.#maxFileSize();
    return (
      typeof name === "string" &&
      name.length > 0 &&
      name.length <= 255 &&
      name !== "." &&
      name !== ".." &&
      !/[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069/\\]/.test(name) &&
      Number.isSafeInteger(size) &&
      size >= 0 &&
      maxSize > 0 &&
      size <= maxSize
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
      lastAck: 0,
      received: 0,
      pendingBytes: 0,
      queue: [],
      busy: false,
      timer: null,
    };
    this.#active.set(peer.key, t);
    let transfers = this.transfers;
    while (transfers.length >= MAX_ENTRIES) {
      const oldest = transfers.find((e) => this.#evictable(e));
      if (!oldest) {
        break;
      }
      transfers = transfers.filter((e) => e !== oldest);
    }
    this.transfers = [...transfers, entry];
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

  // Re-rendering on every chunk is costly for large files; whole percents
  // are all the UI shows.
  #progress(t, progress) {
    if (
      progress === 1 ||
      Math.floor(progress * 100) !== Math.floor(t.entry.progress * 100)
    ) {
      this.#update(t, { progress });
    }
  }

  #arm(t) {
    clearTimeout(t.timer);
    t.timer = setTimeout(() => {
      this.#control(t.peer, "cancel", t.entry.id);
      this.#finish(t, "failed", "timed_out");
    }, this.#timeout);
  }

  #isActive(t) {
    return this.#active.get(t.peer.key) === t;
  }

  #discard(sink, attempt = 0) {
    // A cleanup failure must not resurrect an entry or cause an unhandled rejection.
    if (!sink || (attempt === 0 && this.#retiring.has(sink))) {
      return;
    }
    this.#retiring.set(sink, this.#sinkSizes.get(sink) || 0);
    Promise.resolve()
      .then(() => sink.discard())
      .then(() => this.#retiring.delete(sink))
      .catch(() => {
        // Failed deletion is not reclaimed disk space, so keep the reservation
        // while retrying. After that, the stale-file sweep owns the cleanup and
        // the reservation is dropped so it can't block receives indefinitely.
        if (attempt < DISCARD_RETRY_DELAYS.length) {
          setTimeout(
            () => this.#discard(sink, attempt + 1),
            DISCARD_RETRY_DELAYS[attempt]
          );
        } else {
          this.#retiring.delete(sink);
        }
      });
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
    let congested = false;
    try {
      // Bound responses too: a remote offer flood must not grow our SCTP queue.
      if (peer.channel.bufferedAmount > HIGH_WATER * 2) {
        congested = true;
        throw new Error("Control channel is congested");
      }
      peer.channel.send(JSON.stringify({ type, id, ...metadata }));
      return true;
    } catch {
      // Only the transfer the message belongs to fails, so a peer can't use
      // congestion to end an unrelated transfer.
      const t = this.#active.get(peer.key);
      if (t?.entry.id === id) {
        this.#finish(t, "failed", "channel_unavailable");
      }
      // Congestion clears on its own; a channel that can't send is gone.
      if (!congested) {
        this.disconnect(peer.roomId, peer.userId);
      }
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
      if (!this.#withinOfferLimit(this.#incomingOffers, peer.userId)) {
        this.#control(peer, "reject", id);
        return;
      }
      this.#incomingOffers.push({ userId: peer.userId, at: this.#now() });
      const incomingCount = [...this.#active.values()].filter(
        (transfer) => transfer.entry.direction === "incoming"
      ).length;
      if (
        !this.#receiveAllowed(peer.roomId, peer.userId) ||
        t ||
        incomingCount >= 4 ||
        !this.#hasRoom() ||
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
      this.#progress(t, t.acknowledged / t.entry.size);
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
        this.#progress(t, t.offset / t.entry.size);
        this.#arm(t);
        // Ack whenever the queue drains so the sender never stalls on a
        // coalesced ack.
        if (t.queue.length === 0 || t.offset - t.lastAck >= ACK_INTERVAL) {
          if (!this.#control(t.peer, "ack", t.entry.id, { offset: t.offset })) {
            return;
          }
          t.lastAck = t.offset;
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
        this.#finish(t, "failed", "send_failed");
      }
    } finally {
      t.pumping = false;
    }
  }
}
