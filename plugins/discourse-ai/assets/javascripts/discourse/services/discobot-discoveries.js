import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel, later } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import SmoothStreamer from "../lib/smooth-streamer";

const DISCOVERY_TIMEOUT_MS = 20000;

export function buildRequestId(cryptoProvider = globalThis.crypto) {
  if (cryptoProvider.randomUUID) {
    return cryptoProvider.randomUUID();
  }

  const bytes = new Uint8Array(16);
  cryptoProvider.getRandomValues(bytes);
  bytes[6] = (bytes[6] % 16) + 64;
  bytes[8] = (bytes[8] % 64) + 128;
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0"));

  return `${hex.slice(0, 4).join("")}-${hex.slice(4, 6).join("")}-${hex
    .slice(6, 8)
    .join("")}-${hex.slice(8, 10).join("")}-${hex.slice(10).join("")}`;
}

export default class DiscobotDiscoveries extends Service {
  // We use this to retain state after search menu gets closed.
  // Similar to discourse/discourse#25504
  @service a11y;
  @service currentUser;
  @service siteSettings;

  @tracked discovery = "";
  @tracked lastQuery = "";
  @tracked discoveryTimedOut = false;
  @tracked loadingDiscoveries = false;
  @tracked mode = "ask";
  @tracked sources = [];
  @tracked activeRequestId = "";
  @tracked answerable = null;
  @tracked errorMessage = "";
  @tracked discoveryTitle = "";

  @tracked
  smoothStreamer = new SmoothStreamer(
    () => this.discovery,
    (newValue) => (this.discovery = newValue),
    undefined,
    { smoothCompletion: true }
  );

  discoveryTimeout = null;

  constructor() {
    super(...arguments);

    this.mode =
      this.siteSettings.ai_discover_default_mode === "search"
        ? "search"
        : "ask";
  }

  async onDiscoveryUpdate(update) {
    if (update.request_id !== this.activeRequestId) {
      return;
    }

    if (update.done) {
      this.cancelDiscoveryTimeout();
    } else {
      this.scheduleDiscoveryTimeout();
    }

    if (update.sources) {
      this.sources = update.sources;
    }

    if (update.answerable !== undefined) {
      this.answerable = update.answerable;
    }

    if (update.ai_discover_title !== undefined) {
      this.discoveryTitle = update.ai_discover_title;
    }

    if (update.error) {
      this.failDiscovery(
        update.message ||
          i18n("discourse_ai.discobot_discoveries.request_failed")
      );
      return;
    }

    if (update.ai_discover_reply === undefined) {
      return;
    }

    if (!this.discovery) {
      this.discovery = "";
    }

    this.loadingDiscoveries = false;
    this.smoothStreamer.updateResult(update, "ai_discover_reply");

    if (update.done) {
      const message =
        update.answerable === false
          ? i18n("discourse_ai.discobot_discoveries.no_answer")
          : i18n("discourse_ai.discobot_discoveries.answer_ready");
      this.a11y.announce(message, "polite");
    }
  }

  resetDiscovery() {
    this.cancelDiscoveryTimeout();
    this.loadingDiscoveries = false;
    this.discovery = "";
    this.discoveryTimedOut = false;
    this.sources = [];
    this.activeRequestId = "";
    this.answerable = null;
    this.errorMessage = "";
    this.discoveryTitle = "";
    this.smoothStreamer.resetStreaming();
  }

  get showDiscoveryTitle() {
    return Boolean(
      this.discovery.length > 0 ||
      this.sources.length > 0 ||
      this.loadingDiscoveries ||
      this.discoveryTimedOut ||
      this.answerable === false ||
      this.errorMessage
    );
  }

  get isStreaming() {
    return this.smoothStreamer.isStreaming;
  }

  get streamedText() {
    return this.smoothStreamer?.renderedText;
  }

  setMode(mode) {
    if (!["search", "ask"].includes(mode)) {
      return;
    }

    this.mode = mode;
  }

  @action
  async triggerDiscovery(query) {
    if (this.currentUser?.user_option?.ai_search_discoveries === false) {
      return;
    }

    const normalizedQuery = query?.trim();

    if (this.lastQuery === normalizedQuery) {
      return;
    }

    this.resetDiscovery();

    if (!normalizedQuery) {
      return;
    }

    const requestId = buildRequestId();
    this.loadingDiscoveries = true;
    this.activeRequestId = requestId;

    this.scheduleDiscoveryTimeout();

    try {
      this.lastQuery = normalizedQuery;

      const response = await ajax("/discourse-ai/discoveries/reply", {
        type: "POST",
        data: { query: normalizedQuery, request_id: requestId },
      });

      if (response.request_id !== requestId) {
        throw new Error("Discovery request ID mismatch");
      }
    } catch {
      if (
        this.lastQuery === normalizedQuery &&
        this.activeRequestId === requestId
      ) {
        this.lastQuery = "";
      }

      if (this.activeRequestId === requestId) {
        this.failDiscovery(
          i18n("discourse_ai.discobot_discoveries.request_failed")
        );
      }
    }
  }

  failDiscovery(message) {
    this.cancelDiscoveryTimeout();
    this.loadingDiscoveries = false;
    this.discovery = "";
    this.sources = [];
    this.answerable = null;
    this.errorMessage = message;
    this.discoveryTitle = "";
    this.discoveryTimedOut = false;
    this.lastQuery = "";
    this.activeRequestId = "";
    this.smoothStreamer.resetStreaming();
    this.a11y.announce(message, "assertive");
  }

  timeoutDiscovery() {
    this.cancelDiscoveryTimeout();
    this.loadingDiscoveries = false;
    this.discovery = "";
    this.sources = [];
    this.answerable = null;
    this.errorMessage = "";
    this.discoveryTitle = "";
    this.discoveryTimedOut = true;
    this.lastQuery = "";
    this.activeRequestId = "";
    this.smoothStreamer.resetStreaming();
    this.a11y.announce(
      i18n("discourse_ai.discobot_discoveries.timed_out"),
      "assertive"
    );
  }

  scheduleDiscoveryTimeout() {
    this.cancelDiscoveryTimeout();
    this.discoveryTimeout = later(
      this,
      this.timeoutDiscovery,
      DISCOVERY_TIMEOUT_MS
    );
  }

  cancelDiscoveryTimeout() {
    if (this.discoveryTimeout) {
      cancel(this.discoveryTimeout);
      this.discoveryTimeout = null;
    }
  }
}
