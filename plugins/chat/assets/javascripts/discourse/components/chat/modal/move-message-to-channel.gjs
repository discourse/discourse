import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isBlank } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ChatChannelChooser from "../../chat-channel-chooser";

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
      i18n("chat.move_to_channel.instructions", {
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

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="chat-modal-move-message-to-channel"
      @inline={{@inline}}
      @title={{i18n "chat.move_to_channel.title"}}
    >
      <:body>
        {{#if this.selectedMessageCount}}
          <p>{{this.instructionsText}}</p>
        {{/if}}

        <ChatChannelChooser
          @content={{this.availableChannels}}
          @value={{this.destinationChannelId}}
          @nameProperty="title"
          class="chat-modal-move-message-to-channel__channel-chooser"
        />
      </:body>
      <:footer>
        <DButton
          @icon="right-from-bracket"
          @disabled={{this.disableMoveButton}}
          @action={{this.moveMessages}}
          @label="chat.move_to_channel.confirm_move"
          class="btn-primary"
        />
        <DButton @label="cancel" @action={{@closeModal}} class="btn-flat" />
      </:footer>
    </DModal>
  </template>
}
