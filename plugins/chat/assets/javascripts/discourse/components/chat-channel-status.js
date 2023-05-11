import I18n from "I18n";
import Component from "@glimmer/component";
import {
  CHANNEL_STATUSES,
  channelStatusIcon,
} from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ChatChannelStatus extends Component {
  LONG_FORMAT = "long";
  SHORT_FORMAT = "short";
  VALID_FORMATS = [this.SHORT_FORMAT, this.LONG_FORMAT];

  get format() {
    return this.VALID_FORMATS.includes(this.args.format)
      ? this.args.format
      : this.LONG_FORMAT;
  }

  get shouldRender() {
    return this.args.channel.status !== CHANNEL_STATUSES.open;
  }

  get channelStatusMessage() {
    if (this.format === this.LONG_FORMAT) {
      return this.#longStatusMessage(this.args.channel.status);
    } else {
      return this.#shortStatusMessage(this.args.channel.status);
    }
  }

  get channelStatusIcon() {
    return channelStatusIcon(this.args.channel.status);
  }

  #shortStatusMessage(status) {
    switch (status) {
      case CHANNEL_STATUSES.archived:
        return I18n.t("chat.channel_status.archived");
      case CHANNEL_STATUSES.closed:
        return I18n.t("chat.channel_status.closed");
      case CHANNEL_STATUSES.open:
        return I18n.t("chat.channel_status.open");
      case CHANNEL_STATUSES.readOnly:
        return I18n.t("chat.channel_status.read_only");
    }
  }

  #longStatusMessage(status) {
    switch (status) {
      case CHANNEL_STATUSES.archived:
        return I18n.t("chat.channel_status.archived_header");
      case CHANNEL_STATUSES.closed:
        return I18n.t("chat.channel_status.closed_header");
      case CHANNEL_STATUSES.open:
        return I18n.t("chat.channel_status.open_header");
      case CHANNEL_STATUSES.readOnly:
        return I18n.t("chat.channel_status.read_only_header");
    }
  }
}
