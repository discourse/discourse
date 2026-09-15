import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import addEventToCalendar from "../../lib/add-event-to-calendar";

export default class CalendarPrompt extends Component {
  @service currentUser;
  @service router;

  @tracked dismissed = false;

  get subscribedMessage() {
    const calendarUrl = this.router.urlFor(
      "preferences.calendar-subscriptions",
      this.currentUser.username
    );

    return trustHTML(
      i18n("discourse_events.calendar_prompt.subscribed", {
        calendarUrl: escapeExpression(calendarUrl),
      })
    );
  }

  @action
  dismiss() {
    this.dismissed = true;
  }

  @action
  add() {
    addEventToCalendar(this.args.event);
    this.dismiss();
  }

  @action
  preferences() {
    this.router.transitionTo(
      "preferences.calendar-subscriptions",
      this.currentUser.username
    );
  }

  <template>
    {{#unless this.dismissed}}
      <section class="event-calendar-prompt">
        <div class="event-calendar-prompt__heading">
          {{dIcon "far-calendar-plus" class="event-calendar-prompt__icon"}}
          <p role="status">
            {{#if @hasSubscription}}
              {{this.subscribedMessage}}
            {{else}}
              {{i18n "discourse_events.calendar_prompt.title"}}
            {{/if}}
          </p>
          <DButton
            class="btn-transparent event-calendar-prompt__dismiss"
            @action={{this.dismiss}}
            @ariaLabel="discourse_events.calendar_prompt.dismiss"
            @icon="xmark"
          />
        </div>
        {{#unless @hasSubscription}}
          <div class="event-calendar-prompt__actions">
            <DButton
              class="btn-primary"
              @action={{this.add}}
              @label="discourse_post_event.add_to_calendar"
            />
            <DButton
              class="btn-link event-calendar-prompt__settings"
              @action={{this.preferences}}
              @label="discourse_events.calendar_prompt.subscribe"
            />
          </div>
        {{/unless}}
      </section>
    {{/unless}}
  </template>
}
