import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const PAUSE_URL = "/discourse-calendar/livestream/notification-pause";

// Pauses notifications for as long as the meeting is open, with a toast
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

    // Leaving the meeting, or closing the tab, is a full page load, which never
    // tears the component down.
    window.addEventListener("pagehide", this.resumeOnUnload);

    // Someone already in do not disturb has settled this for themselves.
    if (!this.notifications.isInDoNotDisturb) {
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
      // interrupting the meeting over.
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
      autoClose: false,
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

  #takePauseKey() {
    const pauseKey = this.#pauseKey;
    this.#pauseKey = null;
    return pauseKey;
  }

  #resumeUrl(pauseKey) {
    return `${PAUSE_URL}/${pauseKey}.json`;
  }
}
