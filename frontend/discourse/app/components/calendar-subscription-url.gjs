import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { clipboardCopy } from "discourse/lib/utilities";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class CalendarSubscriptionUrl extends Component {
  @tracked copied = false;

  get webcalUrl() {
    return this.args.url.replace(/^https?:\/\//, "webcal://");
  }

  get googleCalendarUrl() {
    return `https://calendar.google.com/calendar/r?cid=${encodeURIComponent(this.webcalUrl)}`;
  }

  get outlookCalendarUrl() {
    return `https://outlook.live.com/owa?path=/calendar/action/compose&rru=addsubscription&url=${encodeURIComponent(this.args.url)}&name=${encodeURIComponent(this.args.label)}`;
  }

  @action
  async copy(e) {
    e.preventDefault();
    await clipboardCopy(this.args.url);
    this.copied = true;
    setTimeout(() => (this.copied = false), 2000);
  }

  <template>
    <div class="calendar-subscription-url">
      <div class="calendar-subscription-url__header">
        <span class="calendar-subscription-url__label">{{@label}}</span>
        <span
          class="calendar-subscription-url__description"
        >{{@description}}</span>
      </div>

      <div class="calendar-subscription-url__actions">
        <a
          class="btn btn-default btn-small"
          href={{@url}}
          {{on "click" this.copy}}
        >
          {{dIcon (if this.copied "check" "copy")}}
          {{if
            this.copied
            (i18n "user.calendar_subscriptions.copied")
            (i18n "user.calendar_subscriptions.copy")
          }}
        </a>
        <a
          class="btn btn-flat btn-small"
          href={{this.googleCalendarUrl}}
          rel="noopener noreferrer"
          target="_blank"
        >
          {{dIcon "fab-google"}}
          {{i18n "user.calendar_subscriptions.add_to_google"}}
        </a>
        <a
          class="btn btn-flat btn-small"
          href={{this.outlookCalendarUrl}}
          rel="noopener noreferrer"
          target="_blank"
        >
          {{dIcon "fab-microsoft"}}
          {{i18n "user.calendar_subscriptions.add_to_outlook"}}
        </a>
        <a class="btn btn-flat btn-small" href={{this.webcalUrl}}>
          {{dIcon "fab-apple"}}
          {{i18n "user.calendar_subscriptions.add_to_apple"}}
        </a>
      </div>
    </div>
  </template>
}
