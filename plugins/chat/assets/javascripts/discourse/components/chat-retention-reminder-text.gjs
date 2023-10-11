import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import I18n from "I18n";

export default class ChatRetentionReminderText extends Component {
  @service siteSettings;

  get text() {
    if (this.args.channel.isDirectMessageChannel) {
      if (this.#countForChannelType > 0) {
        return I18n.t("chat.retention_reminders.dm", {
          count: this.siteSettings.chat_dm_retention_days,
        });
      } else {
        return I18n.t("chat.retention_reminders.dm_none");
      }
    } else {
      if (this.#countForChannelType > 0) {
        return I18n.t("chat.retention_reminders.public", {
          count: this.siteSettings.chat_channel_retention_days,
        });
      } else {
        return I18n.t("chat.retention_reminders.public_none");
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
