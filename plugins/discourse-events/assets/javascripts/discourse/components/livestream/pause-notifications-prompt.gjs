import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

// An event without an end time has nothing to pause until, and leaving the page
// is what normally ends the pause, so this only bounds a tab left open.
const OPEN_ENDED_PAUSE_MINUTES = 180;

export default class LivestreamPauseNotificationsPrompt extends Component {
  @service currentUser;
  @service notifications;
  @service session;

  @tracked answered = false;
  @tracked pausing = false;

  // Only a pause started here is lifted on the way out: one the user already
  // had is theirs to end.
  #pausedHere = false;
  #pauseRequest = null;

  constructor() {
    super(...arguments);

    // Leaving the meeting, or closing the tab, is a full page load, which never
    // tears the component down.
    window.addEventListener("pagehide", this.liftOnUnload);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    window.removeEventListener("pagehide", this.liftOnUnload);

    if (!this.#pausedHere) {
      return;
    }

    this.#pausedHere = false;

    // Waits out a pause still being saved, which would otherwise land after
    // the lift and stay on. A failure is left alone: the pause still expires
    // with the event.
    Promise.resolve(this.#pauseRequest)
      .then(() => this.currentUser.leaveDoNotDisturb())
      .catch(() => {});
  }

  // Someone already in do not disturb has answered the question for themselves.
  get showPrompt() {
    return (
      !this.args.hidden &&
      !this.answered &&
      !this.notifications.isInDoNotDisturb
    );
  }

  // Bounds the pause by the event as scheduled when it starts, so it does not
  // outlive the meeting even when the page is never left.
  get pauseMinutes() {
    const { allDay, startsAt, endsAt } = this.args.event ?? {};
    let pauseEndsAt;

    if (allDay) {
      pauseEndsAt = moment(endsAt || startsAt).endOf("day");
    } else if (endsAt) {
      pauseEndsAt = moment(endsAt);
    } else {
      return OPEN_ENDED_PAUSE_MINUTES;
    }

    return Math.max(1, Math.ceil(pauseEndsAt.diff(moment(), "minutes", true)));
  }

  @action
  async pause() {
    this.pausing = true;
    this.#pausedHere = true;
    this.#pauseRequest = this.currentUser.enterDoNotDisturbFor(
      this.pauseMinutes
    );

    try {
      await this.#pauseRequest;
      this.answered = true;
    } catch (e) {
      this.#pausedHere = false;
      popupAjaxError(e);
    } finally {
      this.#pauseRequest = null;
      this.pausing = false;
    }
  }

  @action
  dismiss() {
    this.answered = true;
  }

  @bind
  liftOnUnload() {
    if (!this.#pausedHere) {
      return;
    }

    this.#pausedHere = false;

    fetch(getURL("/do-not-disturb.json"), {
      method: "DELETE",
      keepalive: true,
      headers: { "X-CSRF-Token": this.session.csrfToken },
    });
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
