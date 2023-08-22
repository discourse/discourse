import Component from "@glimmer/component";
import { isBlank } from "@ember/utils";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { htmlSafe } from "@ember/template";
import I18n from "I18n";

export default class ChatModalMoveMessageToChannel extends Component {
  @service chat;
  @service chatApi;
  @service router;
  @service chatChannelsManager;

  @tracked destinationChannelId;

  get sourceChannel() {
    return this.args.model.sourceChannel;
  }

  get selectedMessageIds() {
    return this.args.model.selectedMessageIds;
  }

  get selectedMessageCount() {
    return this.selectedMessageIds?.length;
  }

  get disableMoveButton() {
    return isBlank(this.destinationChannelId);
  }

  get availableChannels() {
    return (
      this.args.model.availableChannels ||
      this.chatChannelsManager.publicMessageChannels
    ).rejectBy("id", this.sourceChannel.id);
  }

  get instructionsText() {
    return htmlSafe(
      I18n.t("chat.move_to_channel.instructions", {
        channelTitle: this.sourceChannel.escapedTitle,
        count: this.selectedMessageCount,
      })
    );
  }

  @action
  moveMessages() {
    return this.chatApi
      .moveChannelMessages(this.sourceChannel.id, {
        message_ids: this.selectedMessageIds,
        destination_channel_id: this.destinationChannelId,
      })
      .then((response) => {
        this.args.closeModal();
        this.router.transitionTo(
          "chat.channel.near-message",
          "-",
          response.destination_channel_id,
          response.first_moved_message_id
        );
      })
      .catch(popupAjaxError);
  }
}
