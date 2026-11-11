import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const PAUSE_URL = "/discourse-calendar/livestream/notification-pause";

// A reload loads the webinar again before the pause the last load ended is
// gone, so the load that ends one leaves a note for the next to find.
const UNLOAD_MARK_KEY = "discourse-events-livestream-notification-pause-ended";
const UNLOAD_MARK_TTL_MS = 30000;

// Pauses notifications for as long as the webinar is open, with a toast
// offering a way out for anyone who would rather keep them.
export default class LivestreamNotificationPause extends Component {
  @service currentUser;
  @service notifications;
  @service session;
  @service toasts;

  // Identifies the pause started here, so leaving ends that one alone and the
  // server can order the two even when leaving overtakes starting.
  #pauseKey = null;
  #toast = null;

  constructor() {
    super(...arguments);

    // Leaving the webinar, or closing the tab, is a full page load, which never
    // tears the component down.
    window.addEventListener("pagehide", this.resumeOnUnload);

    // Someone already in do not disturb has settled this for themselves,
    // unless what they are in is the pause this webinar just ended.
    if (this.#takeUnloadMark() || !this.notifications.isInDoNotDisturb) {
      this.#pause();
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);

    window.removeEventListener("pagehide", this.resumeOnUnload);
    this.#closeToast();

    const pauseKey = this.#takePauseKey();

    if (pauseKey) {
      // A failure is left alone: the pause still ends with the event.
      ajax(this.#resumeUrl(pauseKey), { type: "DELETE" }).catch(() => {});
    }
  }

  @action
  async resume() {
    const pauseKey = this.#takePauseKey();
    this.#closeToast();

    if (!pauseKey) {
      return;
    }

    try {
      await ajax(this.#resumeUrl(pauseKey), { type: "DELETE" });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @bind
  resumeOnUnload() {
    const pauseKey = this.#takePauseKey();

    if (!pauseKey) {
      return;
    }

    fetch(getURL(this.#resumeUrl(pauseKey)), {
      method: "DELETE",
      keepalive: true,
      headers: { "X-CSRF-Token": this.session.csrfToken },
    });

    try {
      sessionStorage.setItem(
        UNLOAD_MARK_KEY,
        JSON.stringify({ topicId: this.args.topicId, at: Date.now() })
      );
    } catch {
      // Without storage a reload is treated like any other arrival.
    }
  }

  async #pause() {
    const pauseKey = crypto.randomUUID();
    this.#pauseKey = pauseKey;

    let response;
    try {
      response = await ajax(`${PAUSE_URL}.json`, {
        type: "POST",
        data: { topic_id: this.args.topicId, pause_key: pauseKey },
      });
    } catch {
      // Nobody asked for the pause, so failing to start it is not worth
      // interrupting the webinar over.
      if (this.#pauseKey === pauseKey) {
        this.#pauseKey = null;
      }
      return;
    }

    // Left, or resumed, while the pause was starting.
    if (this.isDestroying || this.#pauseKey !== pauseKey) {
      return;
    }

    this.currentUser.updateDoNotDisturbStatus(response.ends_at);
    this.#showToast();
  }

  #showToast() {
    this.#toast = this.toasts.default({
      duration: "extra-long",
      showProgressBar: true,
      data: {
        icon: "bell-slash",
        message: i18n(
          "discourse_events.livestream.zoom.pause_notifications.paused"
        ),
        actions: [
          {
            label: i18n(
              "discourse_events.livestream.zoom.pause_notifications.resume"
            ),
            class: "btn-default btn-small",
            action: this.resume,
          },
        ],
      },
    });
  }

  #closeToast() {
    if (this.#toast) {
      this.toasts.close(this.#toast);
      this.#toast = null;
    }
  }

  #takeUnloadMark() {
    try {
      const mark = JSON.parse(sessionStorage.getItem(UNLOAD_MARK_KEY));
      sessionStorage.removeItem(UNLOAD_MARK_KEY);

      return (
        mark?.topicId === this.args.topicId &&
        Date.now() - mark.at < UNLOAD_MARK_TTL_MS
      );
    } catch {
      return false;
    }
  }

  #takePauseKey() {
    const pauseKey = this.#pauseKey;
    this.#pauseKey = null;
    return pauseKey;
  }

  #resumeUrl(pauseKey) {
    return `${PAUSE_URL}/${pauseKey}.json`;
  }
}
