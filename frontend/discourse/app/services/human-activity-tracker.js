import { cancel } from "@ember/runloop";
import Service, { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";
import {
  browserAttention,
  onBrowserAttentionChange,
  removeOnBrowserAttentionChange,
} from "discourse/lib/user-presence";

const ENGAGEMENT_PATH = "/srv/se";

const EVENT_COUNTERS = {
  mousedown: "click_events",
  keydown: "key_events",
  touchstart: "touch_events",
  scroll: "scroll_events",
  popstate: "back_forward_events",
};

const MAX_HUMAN_STEP = 100;

const FLUSH_DELAY_MS = 3 * 60 * 1000;

const THROTTLE_MS = 3000;

export default class HumanActivityTracker extends Service {
  @service siteSettings;

  now = () => performance.now();

  transport = (body) => {
    navigator.sendBeacon?.(
      getURL(ENGAGEMENT_PATH),
      new Blob([JSON.stringify(body)], { type: "application/json" })
    );
  };

  scheduleFlush = (callback) => discourseLater(callback, FLUSH_DELAY_MS);

  #sessionId;
  #startedAt;
  #firstInteractionAt = null;
  #lastPosition = null;
  #flushTimer = null;
  #engagedMs = 0;
  #engagedSince = null;
  #lastSentMs = null;
  #counts;
  #activityListener;
  #mouseMoveListener;
  #attentionListener;
  #pagehideListener;

  willDestroy() {
    super.willDestroy(...arguments);
    this.stop();
  }

  start() {
    this.#sessionId = document.querySelector(
      "meta[name=discourse-track-view-session-id]"
    )?.content;
    if (!this.#sessionId) {
      return;
    }

    this.#startedAt = this.now();
    this.#counts = {
      mouse_move_events: 0,
      click_events: 0,
      key_events: 0,
      scroll_events: 0,
      touch_events: 0,
      back_forward_events: 0,
    };

    this.#activityListener = (event) => this.#handleActivity(event);
    this.#mouseMoveListener = (event) => this.#handleMouseMove(event);
    this.#attentionListener = (attention) =>
      this.#handleAttentionChange(attention);
    this.#pagehideListener = () => this.#flush({ force: true });

    Object.keys(EVENT_COUNTERS).forEach((eventName) => {
      window.addEventListener(eventName, this.#activityListener, {
        passive: true,
      });
    });
    window.addEventListener("mousemove", this.#mouseMoveListener, {
      passive: true,
    });
    onBrowserAttentionChange(this.#attentionListener);
    window.addEventListener("pagehide", this.#pagehideListener);

    this.#handleAttentionChange(browserAttention());
    this.#scheduleNextFlush();
  }

  #scheduleNextFlush() {
    this.#flushTimer = this.scheduleFlush(() => {
      this.#flush();
      this.#scheduleNextFlush();
    });
  }

  stop() {
    if (this.#flushTimer) {
      cancel(this.#flushTimer);
      this.#flushTimer = null;
    }

    if (this.#activityListener) {
      Object.keys(EVENT_COUNTERS).forEach((eventName) => {
        window.removeEventListener(eventName, this.#activityListener);
      });
      this.#activityListener = null;
    }
    if (this.#mouseMoveListener) {
      window.removeEventListener("mousemove", this.#mouseMoveListener);
      this.#mouseMoveListener = null;
    }
    if (this.#attentionListener) {
      removeOnBrowserAttentionChange(this.#attentionListener);
      this.#attentionListener = null;
    }
    if (this.#pagehideListener) {
      window.removeEventListener("pagehide", this.#pagehideListener);
      this.#pagehideListener = null;
    }
  }

  #handleActivity(event) {
    this.#counts[EVENT_COUNTERS[event.type]]++;
    this.#markInteraction();
  }

  #handleMouseMove(event) {
    const position = { x: event.clientX, y: event.clientY };

    if (this.#lastPosition) {
      const distance = Math.hypot(
        position.x - this.#lastPosition.x,
        position.y - this.#lastPosition.y
      );

      if (distance > 0 && distance <= MAX_HUMAN_STEP) {
        this.#counts.mouse_move_events++;
        this.#markInteraction();
      }
    }

    this.#lastPosition = position;
  }

  #handleAttentionChange({ focused, visible }) {
    const engaged = focused && visible;

    if (engaged && this.#engagedSince === null) {
      this.#engagedSince = this.now();
    } else if (!engaged && this.#engagedSince !== null) {
      this.#engagedMs += this.now() - this.#engagedSince;
      this.#engagedSince = null;
      this.#flush();
    }
  }

  #markInteraction() {
    this.#firstInteractionAt ??= this.now();
  }

  #engagedSeconds() {
    const live =
      this.#engagedSince === null ? 0 : this.now() - this.#engagedSince;
    return Math.min(
      Math.floor((this.#engagedMs + live) / 1000),
      this.siteSettings.browser_pageview_max_engaged_seconds
    );
  }

  #buildPayload() {
    return {
      session_id: this.#sessionId,
      ...this.#counts,
      engaged_seconds: this.#engagedSeconds(),
      time_to_first_interaction_ms:
        this.#firstInteractionAt === null
          ? null
          : Math.round(this.#firstInteractionAt - this.#startedAt),
    };
  }

  #flush({ force = false } = {}) {
    if (force && this.#flushTimer) {
      cancel(this.#flushTimer);
      this.#flushTimer = null;
    }

    const total = Object.values(this.#counts).reduce((sum, n) => sum + n, 0);
    if (total === 0) {
      return;
    }

    const now = this.now();
    if (
      !force &&
      this.#lastSentMs !== null &&
      now - this.#lastSentMs < THROTTLE_MS
    ) {
      return;
    }
    this.#lastSentMs = now;

    this.transport(this.#buildPayload());
  }
}
