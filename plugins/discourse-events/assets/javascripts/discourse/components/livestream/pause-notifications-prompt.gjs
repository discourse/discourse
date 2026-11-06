import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const PAUSE_URL = "/discourse-calendar/livestream/notification-pause";

export default class LivestreamPauseNotificationsPrompt extends Component {
  @service currentUser;
  @service notifications;
  @service session;

  @tracked answered = false;
  @tracked pausing = false;

  // Identifies the pause started here, so leaving ends that one alone and the
  // server can order the two even when leaving overtakes starting.
  #pauseKey = null;

  constructor() {
    super(...arguments);

    // Leaving the meeting, or closing the tab, is a full page load, which never
    // tears the component down.
    window.addEventListener("pagehide", this.resumeOnUnload);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    window.removeEventListener("pagehide", this.resumeOnUnload);

    const pauseKey = this.#takePauseKey();

    if (pauseKey) {
      // A failure is left alone: the pause still ends with the event.
      ajax(this.#resumeUrl(pauseKey), { type: "DELETE" }).catch(() => {});
    }
  }

  // Someone already in do not disturb has answered the question for themselves.
  get showPrompt() {
    return (
      !this.args.hidden &&
      !this.answered &&
      !this.notifications.isInDoNotDisturb
    );
  }

  @action
  async pause() {
    this.pausing = true;
    this.#pauseKey = crypto.randomUUID();

    try {
      const response = await ajax(`${PAUSE_URL}.json`, {
        type: "POST",
        data: { topic_id: this.args.topicId, pause_key: this.#pauseKey },
      });

      this.currentUser.updateDoNotDisturbStatus(response.ends_at);
      this.answered = true;
    } catch (e) {
      this.#pauseKey = null;
      popupAjaxError(e);
    } finally {
      this.pausing = false;
    }
  }

  @action
  dismiss() {
    this.answered = true;
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

  #takePauseKey() {
    const pauseKey = this.#pauseKey;
    this.#pauseKey = null;
    return pauseKey;
  }

  #resumeUrl(pauseKey) {
    return `${PAUSE_URL}/${pauseKey}.json`;
  }

  <template>
    {{#if this.showPrompt}}
      <div
        aria-labelledby="discourse-calendar-livestream-pause-notifications-title"
        class="discourse-calendar-livestream-pause-notifications"
        role="dialog"
      >
        <p
          class="discourse-calendar-livestream-pause-notifications__title"
          id="discourse-calendar-livestream-pause-notifications-title"
        >
          {{i18n "discourse_events.livestream.zoom.pause_notifications.title"}}
        </p>

        <DButton
          class="btn-transparent btn-small discourse-calendar-livestream-pause-notifications__close"
          @action={{this.dismiss}}
          @icon="xmark"
          @title="discourse_events.livestream.zoom.pause_notifications.dismiss"
        />

        <div class="discourse-calendar-livestream-pause-notifications__actions">
          <DButton
            class="btn-primary btn-small"
            @action={{this.pause}}
            @isLoading={{this.pausing}}
            @label="discourse_events.livestream.zoom.pause_notifications.yes"
          />
          <DButton
            class="btn-default btn-small"
            @action={{this.dismiss}}
            @label="discourse_events.livestream.zoom.pause_notifications.no"
          />
        </div>
      </div>
    {{/if}}
  </template>
}
