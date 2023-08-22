import Component from "@glimmer/component";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";
import I18n from "I18n";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class ChatModalToggleChannelStatus extends Component {
  @service chatApi;
  @service router;

  get channel() {
    return this.args.model;
  }

  get buttonLabel() {
    if (this.channel?.isClosed) {
      return "chat.channel_settings.open_channel";
    } else {
      return "chat.channel_settings.close_channel";
    }
  }

  get instructions() {
    if (this.channel?.isClosed) {
      return htmlSafe(I18n.t("chat.channel_open.instructions"));
    } else {
      return htmlSafe(I18n.t("chat.channel_close.instructions"));
    }
  }

  get modalTitle() {
    if (this.channel?.isClosed) {
      return "chat.channel_open.title";
    } else {
      return "chat.channel_close.title";
    }
  }

  @action
  onStatusChange() {
    const status = this.channel.isClosed
      ? CHANNEL_STATUSES.open
      : CHANNEL_STATUSES.closed;

    return this.chatApi
      .updateChannelStatus(this.channel.id, status)
      .then(() => {
        this.args.closeModal();
        this.router.transitionTo("chat.channel", ...this.channel.routeModels);
      })
      .catch(popupAjaxError);
  }
}
