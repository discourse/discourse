import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class CalendarSubscriptionUrl extends Component {
  @tracked copied = false;

  get googleCalendarUrl() {
    const webcalUrl = this.args.url.replace(/^https?:\/\//, "webcal://");
    return `https://calendar.google.com/calendar/r?cid=${encodeURIComponent(webcalUrl)}`;
  }

  @action
  async copy() {
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
      <div class="calendar-subscription-url__field">
        <input
          type="text"
          readonly
          value={{@url}}
          class="calendar-subscription-url__input"
        />
        <DButton
          @action={{this.copy}}
          @icon={{if this.copied "check" "copy"}}
          @translatedLabel={{if
            this.copied
            (i18n "user.calendar_subscriptions.copied")
            (i18n "user.calendar_subscriptions.copy")
          }}
          class={{if
            this.copied
            "btn-primary calendar-subscription-url__copy"
            "btn-default calendar-subscription-url__copy"
          }}
        />
        <a
          href={{this.googleCalendarUrl}}
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-default calendar-subscription-url__google"
        >
          {{icon "fab-google"}}
          {{i18n "user.calendar_subscriptions.add_to_google"}}
        </a>
      </div>
    </div>
  </template>
}
