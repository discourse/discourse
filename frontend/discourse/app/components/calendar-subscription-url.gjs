import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class CalendarSubscriptionUrl extends Component {
  @tracked copied = false;
  @tracked showUrl = false;

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
  async copy() {
    await clipboardCopy(this.args.url);
    this.copied = true;
    setTimeout(() => (this.copied = false), 2000);
  }

  @action
  toggleUrl() {
    this.showUrl = !this.showUrl;
  }

  <template>
    <div class="calendar-subscription-url">
      <div class="calendar-subscription-url__header">
        <span class="calendar-subscription-url__label">{{@label}}</span>
        <span
          class="calendar-subscription-url__description"
        >{{@description}}</span>
      </div>

      <div class="calendar-subscription-url__subscribe">
        <a
          href={{this.googleCalendarUrl}}
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-default btn-small"
        >
          {{icon "fab-google"}}
          {{i18n "user.calendar_subscriptions.add_to_google"}}
        </a>
        <a
          href={{this.outlookCalendarUrl}}
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-default btn-small"
        >
          {{icon "fab-microsoft"}}
          {{i18n "user.calendar_subscriptions.add_to_outlook"}}
        </a>
        <a href={{this.webcalUrl}} class="btn btn-default btn-small">
          {{icon "calendar-days"}}
          {{i18n "user.calendar_subscriptions.add_to_apple"}}
        </a>
        <DButton
          @action={{this.toggleUrl}}
          @icon="link"
          @label="user.calendar_subscriptions.show_url"
          class="btn-flat btn-small calendar-subscription-url__toggle"
        />
      </div>

      {{#if this.showUrl}}
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
              "btn-primary calendar-subscription-url__copy btn-small"
              "btn-default calendar-subscription-url__copy btn-small"
            }}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
