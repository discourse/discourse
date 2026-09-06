import { tracked } from "@glimmer/tracking";
import { cancel } from "@ember/runloop";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";

const MAX_RETRIES = 3;
const RETRY_BACKOFF_MS = 2000;
const RETRY_COOLDOWN_MS = 10_000;
const TICKER_INTERVAL_MS = 1000;

export function isPending(execution) {
  return execution.status === "pending";
}

export function isRunning(execution) {
  return execution.status === "running";
}

export function isLive(execution) {
  return (
    isPending(execution) ||
    isRunning(execution) ||
    execution.status === "waiting"
  );
}

export function formatDuration(startedAt, finishedAt, currentTime) {
  if (!startedAt || (!finishedAt && !currentTime)) {
    return "—";
  }

  const end = finishedAt ? new Date(finishedAt) : currentTime;
  const milliseconds = Math.max(0, end - new Date(startedAt));

  if (!finishedAt && currentTime) {
    return `${Math.floor(milliseconds / 1000)}s`;
  }

  return milliseconds < 1000
    ? `${milliseconds}ms`
    : `${(milliseconds / 1000).toFixed(1)}s`;
}

export class ExecutionProgressStream {
  @tracked currentTime = Date.now();

  #channel = null;
  #lastMessageId = 0;
  #messageBus;
  #messageHandler = null;
  #onGap;
  #onMessage;
  #onRetry;
  #retryCount = 0;
  #retryTimer = null;
  #ticker = null;

  constructor(messageBus, { onMessage, onGap, onRetry }) {
    this.#messageBus = messageBus;
    this.#onMessage = onMessage;
    this.#onGap = onGap;
    this.#onRetry = onRetry;
  }

  set lastMessageId(value) {
    this.#lastMessageId = value;
  }

  subscribe(channel) {
    if (this.#channel) {
      return;
    }

    this.#channel = channel;
    this.#messageHandler = (message, _globalId, messageId) =>
      this.#deliver(message, messageId);
    this.#messageBus.subscribe(
      channel,
      this.#messageHandler,
      this.#lastMessageId
    );
  }

  unsubscribe() {
    if (!this.#channel) {
      return;
    }

    this.#messageBus.unsubscribe(this.#channel, this.#messageHandler);
    this.#channel = null;
    this.#messageHandler = null;
  }

  scheduleRetry(error) {
    if (this.#retryTimer !== null) {
      return;
    }

    if (this.#retryCount >= MAX_RETRIES) {
      this.#retryCount = 0;
      popupAjaxError(error);
      this.#retryTimer = discourseLater(
        () => this.#runRetry(),
        RETRY_COOLDOWN_MS
      );
      return;
    }

    this.#retryCount += 1;
    this.#retryTimer = discourseLater(
      () => this.#runRetry(),
      RETRY_BACKOFF_MS * this.#retryCount
    );
  }

  resetRetry() {
    this.#retryCount = 0;
    if (this.#retryTimer !== null) {
      cancel(this.#retryTimer);
      this.#retryTimer = null;
    }
  }

  startTicker() {
    this.currentTime = Date.now();
    this.#ticker ||= window.setInterval(() => {
      this.currentTime = Date.now();
    }, TICKER_INTERVAL_MS);
  }

  stopTicker() {
    if (this.#ticker) {
      window.clearInterval(this.#ticker);
      this.#ticker = null;
    }
  }

  destroy() {
    this.unsubscribe();
    this.stopTicker();
    this.resetRetry();
  }

  #deliver(message, messageId) {
    if (messageId !== this.#lastMessageId + 1) {
      this.#onGap();
      return;
    }

    this.#lastMessageId = messageId;
    this.resetRetry();
    this.#onMessage(message);
  }

  #runRetry() {
    this.#retryTimer = null;
    this.#onRetry();
  }
}
