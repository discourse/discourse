import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";

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
      return trustHTML(i18n("chat.channel_open.instructions"));
    } else {
      return trustHTML(i18n("chat.channel_close.instructions"));
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

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="chat-modal-toggle-channel-status"
      @inline={{@inline}}
      @title={{i18n this.modalTitle}}
    >
      <:body>
        <p
          class="chat-modal-toggle-channel-status__instructions"
        >{{this.instructions}}</p>
      </:body>
      <:footer>
        <DButton
          @action={{this.onStatusChange}}
          @label={{this.buttonLabel}}
          id="chat-channel-toggle-btn"
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
