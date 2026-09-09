import { ajax } from "discourse/lib/ajax";

export default class SignalingManager {
  static peerKey(roomId, userId) {
    return `${roomId}:${userId}`;
  }

  static #buildPayload(messages) {
    if (messages.length === 1) {
      const [message] = messages;

      if (message.events.length === 1) {
        return {
          ...message.events[0],
          recipient_id: message.recipient_id,
        };
      }

      return {
        recipient_id: message.recipient_id,
        events: message.events,
      };
    }

    return {
      messages: messages.map((message) => ({
        recipient_id: message.recipient_id,
        events: message.events,
      })),
    };
  }

  static #defaultCandidateBatchDelayMs = 75;
  static #defaultCandidateBatchSize = 5;

  static #defaultHttpBatchDelayMs = 200;

  // The server rejects batches with more than 25 events for one recipient;
  // flushing at 20 keeps a candidate batch appended mid-window under that cap.
  static #httpFlushEventThreshold = 20;

  #candidateBatchDelayMs;
  #candidateBatchSize;
  #httpBatchDelayMs;

  #destroyed = false;
  #signalQueues = new Map();
  #signalFlushTimers = new Map();
  #httpSignalQueues = new Map();
  #httpSignalFlushTimers = new Map();

  #isActiveRoom;
  #hasPeer;
  #getParticipantSessionId;
  #requestSignals;

  constructor({
    isActiveRoom,
    hasPeer,
    getParticipantSessionId = () => undefined,
    requestSignals,
    candidateBatchDelayMs = SignalingManager.#defaultCandidateBatchDelayMs,
    candidateBatchSize = SignalingManager.#defaultCandidateBatchSize,
    httpBatchDelayMs = SignalingManager.#defaultHttpBatchDelayMs,
  }) {
    this.#isActiveRoom = isActiveRoom;
    this.#hasPeer = hasPeer;
    this.#getParticipantSessionId = getParticipantSessionId;
    this.#requestSignals =
      requestSignals ??
      ((roomId, payload) =>
        ajax(`/voice/rooms/${roomId}/signal`, {
          type: "POST",
          data: {
            payload,
            participant_session_id: this.#getParticipantSessionId(roomId),
          },
        }));
    this.#candidateBatchDelayMs = candidateBatchDelayMs;
    this.#candidateBatchSize = candidateBatchSize;
    this.#httpBatchDelayMs = httpBatchDelayMs;
  }

  async send(roomId, recipientId, payload) {
    if (this.#destroyed || !roomId || !recipientId || !payload) {
      return;
    }

    if (!this.#isActiveRoom(roomId)) {
      return;
    }

    if (!this.#hasPeer(roomId, recipientId)) {
      return;
    }

    if (payload.type === "candidate") {
      this.#queue(roomId, recipientId, payload);
      return;
    }

    await this.flushQueued(roomId, recipientId);

    if (!this.#isActiveRoom(roomId) || !this.#hasPeer(roomId, recipientId)) {
      return;
    }

    await this.#postSignals(roomId, recipientId, [payload]);
  }

  async flushQueued(roomId, recipientId) {
    const key = SignalingManager.peerKey(roomId, recipientId);
    const queue = this.#signalQueues.get(key);

    if (!queue?.length) {
      return;
    }

    this.#signalQueues.delete(key);

    const timer = this.#signalFlushTimers.get(key);
    if (timer) {
      clearTimeout(timer);
      this.#signalFlushTimers.delete(key);
    }

    if (!this.#isActiveRoom(roomId) || !this.#hasPeer(roomId, recipientId)) {
      return;
    }

    await this.#postSignals(roomId, recipientId, queue);
  }

  clearForPeer(roomId, recipientId) {
    const key = SignalingManager.peerKey(roomId, recipientId);
    const timer = this.#signalFlushTimers.get(key);

    if (timer) {
      clearTimeout(timer);
      this.#signalFlushTimers.delete(key);
    }

    this.#signalQueues.delete(key);

    const entry = this.#httpSignalQueues.get(roomId);
    if (!entry) {
      return;
    }

    entry.recipients?.delete?.(recipientId);

    const [clearedPending, retainedPending] = this.#partitionPending(
      entry.pending,
      new Set(),
      recipientId
    );

    entry.pending = retainedPending;
    this.#settlePending(clearedPending, "resolve");

    if (!entry.recipients.size && !entry.pending.length) {
      this.#httpSignalQueues.delete(roomId);
    }
  }

  clearForRoom(roomId) {
    const prefix = `${roomId}:`;

    Array.from(this.#signalQueues.keys()).forEach((key) => {
      if (!key.startsWith(prefix)) {
        return;
      }

      const timer = this.#signalFlushTimers.get(key);

      if (timer) {
        clearTimeout(timer);
        this.#signalFlushTimers.delete(key);
      }

      this.#signalQueues.delete(key);
    });
  }

  clearHttpQueue(roomId) {
    const timer = this.#httpSignalFlushTimers.get(roomId);
    if (timer) {
      clearTimeout(timer);
      this.#httpSignalFlushTimers.delete(roomId);
    }

    const entry = this.#httpSignalQueues.get(roomId);
    if (!entry) {
      return;
    }

    entry.recipients?.clear?.();
    this.#settlePending(entry.pending || [], "resolve");
    entry.pending = [];
    this.#httpSignalQueues.delete(roomId);
  }

  // Terminal: no further signals are queued or flushed afterwards, so a
  // continuation resumed after teardown cannot schedule a late HTTP flush.
  destroy() {
    this.#destroyed = true;

    this.#signalFlushTimers.forEach((timer) => clearTimeout(timer));
    this.#signalFlushTimers.clear();
    this.#httpSignalFlushTimers.forEach((timer) => clearTimeout(timer));
    this.#httpSignalFlushTimers.clear();
    this.#httpSignalQueues.forEach((entry) => {
      this.#settlePending(entry?.pending || [], "resolve");
    });
    this.#httpSignalQueues.clear();
    this.#signalQueues.clear();
  }

  #queue(roomId, recipientId, payload) {
    const key = SignalingManager.peerKey(roomId, recipientId);
    const queue = this.#signalQueues.get(key) || [];
    queue.push(payload);
    this.#signalQueues.set(key, queue);

    if (queue.length >= this.#candidateBatchSize) {
      this.flushQueued(roomId, recipientId).catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to flush signal queue", error);
      });
      return;
    }

    const existingTimer = this.#signalFlushTimers.get(key);
    if (existingTimer) {
      clearTimeout(existingTimer);
    }

    const timer = setTimeout(() => {
      this.#signalFlushTimers.delete(key);
      this.flushQueued(roomId, recipientId).catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to flush signal queue", error);
      });
    }, this.#candidateBatchDelayMs);

    this.#signalFlushTimers.set(key, timer);
  }

  async #postSignals(roomId, recipientId, events) {
    if (!events?.length || !this.#isActiveRoom(roomId)) {
      return;
    }

    await this.#enqueueHttp(roomId, recipientId, events);
  }

  #enqueueHttp(roomId, recipientId, events) {
    if (this.#destroyed || !roomId || !recipientId || !events?.length) {
      return Promise.resolve();
    }

    let entry = this.#httpSignalQueues.get(roomId);

    if (!entry) {
      entry = {
        recipients: new Map(),
        pending: [],
      };

      this.#httpSignalQueues.set(roomId, entry);
    }

    const roomQueue = entry.recipients;
    const existingEvents = roomQueue.get(recipientId);

    if (existingEvents) {
      existingEvents.push(...events);
    } else {
      roomQueue.set(recipientId, [...events]);
    }

    const promise = new Promise((resolve, reject) => {
      entry.pending.push({ recipientId, resolve, reject });
    });

    const queuedEvents = roomQueue.get(recipientId);
    if (queuedEvents.length >= SignalingManager.#httpFlushEventThreshold) {
      const timer = this.#httpSignalFlushTimers.get(roomId);
      if (timer) {
        clearTimeout(timer);
        this.#httpSignalFlushTimers.delete(roomId);
      }
      this.#flushHttp(roomId).catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to flush HTTP signal queue", error);
      });
    } else {
      this.#scheduleHttpFlush(roomId);
    }

    return promise;
  }

  #scheduleHttpFlush(roomId) {
    if (this.#destroyed || this.#httpSignalFlushTimers.has(roomId)) {
      return;
    }

    const timer = setTimeout(() => {
      this.#httpSignalFlushTimers.delete(roomId);
      this.#flushHttp(roomId).catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to flush HTTP signal queue", error);
      });
    }, this.#httpBatchDelayMs);

    this.#httpSignalFlushTimers.set(roomId, timer);
  }

  async #flushHttp(roomId) {
    const entry = this.#httpSignalQueues.get(roomId);
    if (!entry) {
      return;
    }

    if (!this.#isActiveRoom(roomId)) {
      entry.recipients?.clear?.();
      this.#settlePending(entry.pending.splice(0), "resolve");
      this.#httpSignalQueues.delete(roomId);
      return;
    }

    const roomQueue = entry.recipients;
    const pending = entry.pending;
    entry.recipients = new Map();
    entry.pending = [];

    if (!roomQueue?.size) {
      this.#settlePending(pending, "resolve");
      if (!entry.recipients.size && !entry.pending.length) {
        this.#httpSignalQueues.delete(roomId);
      }
      return;
    }

    const messages = [];
    const activeRecipientIds = new Set();

    roomQueue.forEach((events, recipientId) => {
      if (!events?.length || !this.#hasPeer(roomId, recipientId)) {
        return;
      }

      messages.push({
        recipient_id: recipientId,
        events,
      });
      activeRecipientIds.add(recipientId);
    });

    const [batchPending, droppedPending] = this.#partitionPending(
      pending,
      activeRecipientIds
    );
    this.#settlePending(droppedPending, "resolve");

    if (!messages.length) {
      this.#settlePending(batchPending, "resolve");
      if (!entry.recipients.size && !entry.pending.length) {
        this.#httpSignalQueues.delete(roomId);
      }
      return;
    }

    const payload = SignalingManager.#buildPayload(messages);

    // eslint-disable-next-line no-console
    console.log(
      `[voice] 🚀 sending ${messages.length} batched signal recipient(s) in room ${roomId}`
    );

    try {
      await this.#requestSignals(roomId, payload);

      this.#settlePending(batchPending, "resolve");
    } catch (error) {
      this.#settlePending(batchPending, "reject", error);
      throw error;
    } finally {
      if (!entry.recipients.size && !entry.pending.length) {
        this.#httpSignalQueues.delete(roomId);
      }
    }
  }

  #partitionPending(pending, allowedRecipientIds, clearedRecipientId = null) {
    const batchPending = [];
    const retainedPending = [];

    for (const entry of pending || []) {
      if (clearedRecipientId !== null) {
        if (entry.recipientId === clearedRecipientId) {
          batchPending.push(entry);
        } else {
          retainedPending.push(entry);
        }
        continue;
      }

      if (allowedRecipientIds.has(entry.recipientId)) {
        batchPending.push(entry);
      } else {
        retainedPending.push(entry);
      }
    }

    return [batchPending, retainedPending];
  }

  #settlePending(pending, action, error = null) {
    for (const entry of pending || []) {
      entry?.[action]?.(error);
    }
  }
}
