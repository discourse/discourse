import { cancel } from "@ember/runloop";
import getURL from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";

const ENGAGEMENT_PATH = "/srv/se";

const EVENT_COUNTERS = {
  mousedown: "click_events",
  keydown: "key_events",
  touchstart: "touch_events",
  scroll: "scroll_events",
  wheel: "scroll_events",
  popstate: "back_forward_events",
};

const MAX_HUMAN_STEP = 100;

const FLUSH_DELAY_MS = 3 * 60 * 1000;

export default {
  initialize() {
    const enabled =
      document.querySelector("meta[name=discourse-beacon-pageview-enabled]")
        ?.content === "true";
    this.sessionId = document.querySelector(
      "meta[name=discourse-track-view-session-id]"
    )?.content;
    this.active = enabled && !!this.sessionId;
    if (!this.active) {
      return;
    }

    this.startedAt = performance.now();
    this.firstInteractionAt = null;
    this.lastPosition = null;
    this.flushTimer = null;
    this.engagedMs = 0;
    this.engagedSince = null;
    this.counts = {
      mouse_move_events: 0,
      click_events: 0,
      key_events: 0,
      scroll_events: 0,
      touch_events: 0,
      back_forward_events: 0,
    };

    this.handleActivity = (event) => {
      this.counts[EVENT_COUNTERS[event.type]]++;
      this.markInteraction();
    };

    this.handleMouseMove = (event) => {
      const position = { x: event.clientX, y: event.clientY };

      if (this.lastPosition) {
        const distance = Math.hypot(
          position.x - this.lastPosition.x,
          position.y - this.lastPosition.y
        );

        if (distance > 0 && distance <= MAX_HUMAN_STEP) {
          this.counts.mouse_move_events++;
          this.markInteraction();
        }
      }

      this.lastPosition = position;
    };

    this.updateEngagement = () => {
      const engaged =
        document.visibilityState === "visible" && document.hasFocus();

      if (engaged && this.engagedSince === null) {
        this.engagedSince = performance.now();
      } else if (!engaged && this.engagedSince !== null) {
        this.engagedMs += performance.now() - this.engagedSince;
        this.engagedSince = null;
      }
    };

    this.flush = () => {
      if (this.flushTimer) {
        cancel(this.flushTimer);
        this.flushTimer = null;
      }

      const total = Object.values(this.counts).reduce((sum, n) => sum + n, 0);
      if (total === 0) {
        return;
      }

      const body = JSON.stringify(this.buildPayload());
      navigator.sendBeacon?.(
        getURL(ENGAGEMENT_PATH),
        new Blob([body], { type: "application/json" })
      );
    };

    this.handleVisibilityChange = () => {
      this.updateEngagement();
      if (document.visibilityState === "hidden") {
        this.flush();
      }
    };

    Object.keys(EVENT_COUNTERS).forEach((eventName) => {
      window.addEventListener(eventName, this.handleActivity, {
        passive: true,
      });
    });
    window.addEventListener("mousemove", this.handleMouseMove, {
      passive: true,
    });
    document.addEventListener("visibilitychange", this.handleVisibilityChange);
    window.addEventListener("focus", this.updateEngagement);
    window.addEventListener("blur", this.updateEngagement);
    window.addEventListener("pagehide", this.flush);

    this.updateEngagement();
    this.flushTimer = discourseLater(this.flush, FLUSH_DELAY_MS);
  },

  markInteraction() {
    this.firstInteractionAt ??= performance.now();
  },

  engagedDurationMs() {
    const live =
      this.engagedSince === null ? 0 : performance.now() - this.engagedSince;
    return Math.round(this.engagedMs + live);
  },

  buildPayload() {
    return {
      session_id: this.sessionId,
      ...this.counts,
      engaged_duration_ms: this.engagedDurationMs(),
      time_to_first_interaction_ms:
        this.firstInteractionAt === null
          ? null
          : Math.round(this.firstInteractionAt - this.startedAt),
    };
  },

  teardown() {
    if (!this.active) {
      return;
    }
    this.active = false;

    if (this.flushTimer) {
      cancel(this.flushTimer);
      this.flushTimer = null;
    }

    Object.keys(EVENT_COUNTERS).forEach((eventName) => {
      window.removeEventListener(eventName, this.handleActivity);
    });
    window.removeEventListener("mousemove", this.handleMouseMove);
    document.removeEventListener(
      "visibilitychange",
      this.handleVisibilityChange
    );
    window.removeEventListener("focus", this.updateEngagement);
    window.removeEventListener("blur", this.updateEngagement);
    window.removeEventListener("pagehide", this.flush);
  },
};
