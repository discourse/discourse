import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";
import { clipboardCopy } from "discourse/lib/utilities";
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
          href={{@url}}
          {{on "click" this.copy}}
          class="btn btn-default btn-small"
        >
          {{icon (if this.copied "check" "copy")}}
          {{if
            this.copied
            (i18n "user.calendar_subscriptions.copied")
            (i18n "user.calendar_subscriptions.copy")
          }}
        </a>
        <a
          href={{this.googleCalendarUrl}}
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-flat btn-small"
        >
          {{icon "fab-google"}}
          {{i18n "user.calendar_subscriptions.add_to_google"}}
        </a>
        <a
          href={{this.outlookCalendarUrl}}
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-flat btn-small"
        >
          {{icon "fab-microsoft"}}
          {{i18n "user.calendar_subscriptions.add_to_outlook"}}
        </a>
        <a href={{this.webcalUrl}} class="btn btn-flat btn-small">
          {{icon "fab-apple"}}
          {{i18n "user.calendar_subscriptions.add_to_apple"}}
        </a>
      </div>
    </div>
  </template>
}
