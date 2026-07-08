import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class PushNotificationSelect extends Component {
  @service desktopNotifications;
  @service siteSettings;

  get chatAvailable() {
    return (
      this.siteSettings.chat_enabled && this.args.model.user_option.chat_enabled
    );
  }

  get content() {
    const options = [
      {
        name: i18n("user.desktop_notifications.push_level.none"),
        value: "none",
      },
      { name: i18n("user.desktop_notifications.push_level.all"), value: "all" },
    ];

    if (this.chatAvailable) {
      options.push({
        name: i18n("user.desktop_notifications.push_level.chat_only"),
        value: "chat_only",
      });
    }

    return options;
  }

  get value() {
    if (!this.desktopNotifications.isSubscribed) {
      return "none";
    }

    const level = this.args.model.user_option.push_notification_level;

    if (level === "chat_only" && !this.chatAvailable) {
      return "all";
    }

    return level;
  }

  @action
  async onChange(value) {
    if (value === "none") {
      await this.desktopNotifications.disable();
      return;
    }

    if (!this.desktopNotifications.isSubscribed) {
      await this.desktopNotifications.enable();

      // enable() can fail (denied permission, push registration error) without
      // throwing; don't persist a level for a user who isn't actually subscribed.
      if (!this.desktopNotifications.isSubscribed) {
        return;
      }
    }

    // Persist immediately so the stored level can't disagree with the
    // subscription state that was just changed (e.g. if the user navigates away
    // before using the page's Save button).
    this.args.model.set("user_option.push_notification_level", value);
    await this.args.model
      .save(["push_notification_level"])
      .catch(popupAjaxError);
  }

  <template>
    {{#if this.desktopNotifications.isNotSupported}}
      <DButton
        @icon="bell-slash"
        @label="user.desktop_notifications.not_supported"
        @disabled="true"
        class="btn-default"
      />
    {{else if this.desktopNotifications.isDeniedPermission}}
      <DButton
        @icon="bell-slash"
        @label="user.desktop_notifications.perm_denied_btn"
        @disabled="true"
        class="btn-default"
      />
      <span>
        {{i18n "user.desktop_notifications.perm_denied_expl"}}
      </span>
    {{else}}
      <label class="sr-only">{{i18n
          "user.desktop_notifications.push_level.title"
        }}</label>
      <ComboBox
        @valueProperty="value"
        @content={{this.content}}
        @value={{this.value}}
        @onChange={{this.onChange}}
        class="push-notification-select"
      />
    {{/if}}
  </template>
}
