import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class ChatRetentionReminderText extends Component {
  @service currentUser;
  @service siteSettings;

  get type() {
    return this.args.type ?? "long";
  }

  get #chatSettingsLink() {
    const label = i18n("chat.retention_reminders.chat_settings");
    if (this.currentUser?.admin) {
      const url = getURL("/admin/site_settings/category/chat");
      return `<a href="${url}">${label}</a>`;
    }
    return label;
  }

  get text() {
    const opts = { chatSettingsLink: this.#chatSettingsLink };

    if (this.args.channel.isDirectMessageChannel) {
      if (this.#countForChannelType > 0) {
        return htmlSafe(
          i18n(`chat.retention_reminders.${this.type}`, {
            ...opts,
            count: this.siteSettings.chat_dm_retention_days,
          })
        );
      } else {
        return htmlSafe(
          i18n(`chat.retention_reminders.indefinitely_${this.type}`, opts)
        );
      }
    } else {
      if (this.#countForChannelType > 0) {
        return htmlSafe(
          i18n(`chat.retention_reminders.${this.type}`, {
            ...opts,
            count: this.siteSettings.chat_channel_retention_days,
          })
        );
      } else {
        return htmlSafe(
          i18n(`chat.retention_reminders.indefinitely_${this.type}`, opts)
        );
      }
    }
  }

  get #countForChannelType() {
    return this.args.channel.isDirectMessageChannel
      ? this.siteSettings.chat_dm_retention_days
      : this.siteSettings.chat_channel_retention_days;
  }

  <template>
    <span class="chat-retention-reminder-text">
      {{this.text}}
    </span>
  </template>
}
