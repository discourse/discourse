import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isBlank } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import ChatChannelChooser from "../../chat-channel-chooser";

export default class ChatModalMoveMessageToChannel extends Component {
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
    ).filter((channel) => channel.id !== this.sourceChannel.id);
  }

  get instructionsText() {
    return trustHTML(
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
      class="chat-modal-move-message-to-channel"
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{i18n "chat.move_to_channel.title"}}
    >
      <:body>
        {{#if this.selectedMessageCount}}
          <p>{{this.instructionsText}}</p>
        {{/if}}

        <ChatChannelChooser
          class="chat-modal-move-message-to-channel__channel-chooser"
          @content={{this.availableChannels}}
          @nameProperty="title"
          @value={{this.destinationChannelId}}
        />
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.moveMessages}}
          @disabled={{this.disableMoveButton}}
          @icon="right-from-bracket"
          @label="chat.move_to_channel.confirm_move"
        />
        <DButton class="btn-flat" @action={{@closeModal}} @label="cancel" />
      </:footer>
    </DModal>
  </template>
}
