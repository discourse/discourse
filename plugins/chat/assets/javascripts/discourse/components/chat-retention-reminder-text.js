import Component from "@glimmer/component";
import I18n from "I18n";
import { inject as service } from "@ember/service";

export default class ChatRetentionReminderText extends Component {
  @service siteSettings;

  get text() {
    let prefix = `${this.#baseKey}.${this.#channelTypeKey}`;

    if (this.#countForChannelType > 0) {
      return I18n.t(prefix, { count: this.#countForChannelType });
    }

    return I18n.t(`${prefix}_none`);
  }

  get #baseKey() {
    return "chat.retention_reminders";
  }

  get #channelTypeKey() {
    return this.args.channel.isDirectMessageChannel ? "dm" : "public";
  }

  get #countForChannelType() {
    return this.args.channel.isDirectMessageChannel
      ? this.siteSettings.chat_dm_retention_days
      : this.siteSettings.chat_channel_retention_days;
  }
}
