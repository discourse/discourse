import { tracked } from "@glimmer/tracking";
import { manuallyTrack } from "discourse/lib/tracked-tools";
import openReceiveSink from "./file-receive-sink.js";
import {
  DEFAULT_MAX_FILE_SIZE,
  MAX_CONFIGURED_FILE_SIZE,
} from "./file-transfer-limits.js";

const HEADER_SIZE = 36;
export const MAX_CHUNK_SIZE = 256 * 1024 - HEADER_SIZE;
const MIN_CHUNK_SIZE = 16 * 1024 - HEADER_SIZE;
// Used when the transport does not report its message size limit.
export const CHUNK_SIZE = 64 * 1024 - HEADER_SIZE;
// Throughput is capped near one window per round trip, so this is sized for
// relayed links while still bounding what a peer can make us hold in memory.
export const RECEIVE_WINDOW = 8 * 1024 * 1024;
export const HIGH_WATER = 1024 * 1024;
const LOW_WATER = 256 * 1024;
// Covers a channel that closes, or never fires the event, while we wait.
const DRAIN_POLL_MS = 250;
const READ_AHEAD = 1024 * 1024;
const WRITE_BATCH = 1024 * 1024;
const ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const TERMINAL = new Set(["completed", "rejected", "cancelled", "failed"]);
const MAX_ENTRIES = 100;
const ACK_INTERVAL = 1024 * 1024;
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
  #fileTypeAllowed;
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
    isFileTypeAllowed = () => true,
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
    this.#fileTypeAllowed = isFileTypeAllowed;
    this.#openSink = openSink;
    this.#getMaxFileSize = getMaxFileSize;
    this.#estimateStorage = estimateStorage;
    this.#offerLimit = offerLimit;
    this.#now = now;
  }

  attach(roomId, userId, channel, getMaxMessageSize = () => undefined) {
    this.disconnect(roomId, userId);
    const key = this.#key(roomId, userId);
    const peer = { roomId, userId, channel, key, getMaxMessageSize };
    this.#peers.set(key, peer);
    this.channelsRevision++;
    channel.onopen = () => this.channelsRevision++;
    channel.binaryType = "arraybuffer";
    channel.bufferedAmountLowThreshold = LOW_WATER;
    channel.onbufferedamountlow = () => peer.drained?.();
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
      !this.#validMetadata(file.name, file.size) ||
      !this.#fileTypeAllowed(file.name, {
        roomId,
        userId,
        direction: "outgoing",
      })
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
      "outgoing",
      this.#chunkSizeFor(peer)
    );
    transfer.file = file;
    transfer.header = new TextEncoder().encode(transfer.entry.id);
    this.#control(peer, "offer", transfer.entry.id, {
      name: file.name,
      size: file.size,
      chunkSize: transfer.chunkSize,
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
    if (!this.#validIncoming(t.peer, t.entry.name, t.entry.size)) {
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
        !this.#validIncoming(t.peer, t.entry.name, t.entry.size)
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
        !this.#validIncoming(t.peer, t.entry.name, t.entry.size)
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
      peer.channel.onbufferedamountlow = null;
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

  // The largest frame the transport accepts, so each send is one message.
  #chunkSizeFor(peer) {
    const limit = peer.getMaxMessageSize();
    const chunkSize = limit > 0 ? limit - HEADER_SIZE : CHUNK_SIZE;
    return Math.min(MAX_CHUNK_SIZE, Math.max(MIN_CHUNK_SIZE, chunkSize));
  }

  #validChunkSize(chunkSize) {
    return (
      Number.isSafeInteger(chunkSize) &&
      chunkSize >= MIN_CHUNK_SIZE &&
      chunkSize <= MAX_CHUNK_SIZE
    );
  }

  // Incoming files are checked against the sender's allowed types, not ours.
  #validIncoming(peer, name, size) {
    return (
      this.#validMetadata(name, size) &&
      this.#fileTypeAllowed(name, {
        roomId: peer.roomId,
        userId: peer.userId,
        direction: "incoming",
      })
    );
  }

  #create(peer, id, name, size, direction, chunkSize) {
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
      chunkSize,
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
    t.buffer = null;
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
        data.byteLength <= HEADER_SIZE ||
        data.byteLength > MAX_CHUNK_SIZE + HEADER_SIZE
      ) {
        throw new Error("Invalid frame");
      }
      const id = new TextDecoder().decode(new Uint8Array(data, 0, HEADER_SIZE));
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
        t.pendingBytes + data.byteLength - HEADER_SIZE > RECEIVE_WINDOW ||
        data.byteLength - HEADER_SIZE !==
          Math.min(t.chunkSize, t.entry.size - t.received)
      ) {
        throw new Error("Unexpected bytes or receive window exceeded");
      }
      // Explicit bounded queue, including the currently writing frame. Never
      // append peer-controlled chunks to an unbounded promise chain.
      const chunk = new Uint8Array(data, HEADER_SIZE);
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
    const { type, id, name, size, chunkSize } = message;
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
        !this.#validChunkSize(chunkSize) ||
        !this.#validIncoming(peer, name, size)
      ) {
        this.#control(peer, "reject", id);
        return;
      }
      this.#create(peer, id, name, size, "incoming", chunkSize);
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
          message.offset % t.chunkSize !== 0) ||
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

  // One disk write per chunk is the receive bottleneck on fast links, so
  // whatever queued up behind the previous write goes out together.
  #takeBatch(queue) {
    let size = queue[0].byteLength;
    let count = 1;
    while (
      count < queue.length &&
      size + queue[count].byteLength <= WRITE_BATCH
    ) {
      size += queue[count++].byteLength;
    }
    const chunks = queue.splice(0, count);
    if (count === 1) {
      return chunks[0];
    }
    const batch = new Uint8Array(size);
    let position = 0;
    for (const chunk of chunks) {
      batch.set(chunk, position);
      position += chunk.byteLength;
    }
    return batch;
  }

  #drained(peer) {
    return new Promise((resolve) => {
      const timer = setTimeout(resolve, DRAIN_POLL_MS);
      peer.drained = () => {
        clearTimeout(timer);
        resolve();
      };
    });
  }

  async #write(t) {
    if (t.writing) {
      return;
    }
    t.writing = true;
    try {
      while (this.#isActive(t) && t.queue.length) {
        const chunk = this.#takeBatch(t.queue);
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
        const length = Math.min(t.chunkSize, t.entry.size - t.offset);
        if (
          length === 0 ||
          t.offset - t.acknowledged + length > RECEIVE_WINDOW
        ) {
          return;
        }
        if (t.peer.channel.bufferedAmount > HIGH_WATER) {
          await this.#drained(t.peer);
          continue;
        }
        if (!t.buffer || t.bufferOffset === t.buffer.byteLength) {
          // A whole number of chunks, so only the file's last frame is short.
          const readSize =
            t.chunkSize * Math.max(1, Math.floor(READ_AHEAD / t.chunkSize));
          const end = Math.min(t.entry.size, t.offset + readSize);
          const buffer = new Uint8Array(
            await t.file.slice(t.offset, end).arrayBuffer()
          );
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
          if (buffer.byteLength !== end - t.offset) {
            throw new Error("File changed while sending");
          }
          t.buffer = buffer;
          t.bufferOffset = 0;
        }
        const frame = new Uint8Array(HEADER_SIZE + length);
        frame.set(t.header);
        frame.set(
          t.buffer.subarray(t.bufferOffset, t.bufferOffset + length),
          HEADER_SIZE
        );
        t.bufferOffset += length;
        // Set the offset before sending: test transports may deliver immediately.
        t.offset += length;
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
