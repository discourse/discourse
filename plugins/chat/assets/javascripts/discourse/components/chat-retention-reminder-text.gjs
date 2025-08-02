import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class ChatRetentionReminderText extends Component {
  @service siteSettings;

  get type() {
    return this.args.type ?? "long";
  }

  get text() {
    if (this.args.channel.isDirectMessageChannel) {
      if (this.#countForChannelType > 0) {
        return i18n(`chat.retention_reminders.${this.type}`, {
          count: this.siteSettings.chat_dm_retention_days,
        });
      } else {
        return i18n(`chat.retention_reminders.indefinitely_${this.type}`);
      }
    } else {
      if (this.#countForChannelType > 0) {
        return i18n(`chat.retention_reminders.${this.type}`, {
          count: this.siteSettings.chat_channel_retention_days,
        });
      } else {
        return i18n(`chat.retention_reminders.indefinitely_${this.type}`);
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
