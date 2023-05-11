import Component from "@ember/component";
import I18n from "I18n";
import { reads } from "@ember/object/computed";
import { isBlank } from "@ember/utils";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { htmlSafe } from "@ember/template";

export default class MoveToChannelModalInner extends Component {
  @service chat;
  @service chatApi;
  @service router;
  @service chatChannelsManager;

  tagName = "";
  sourceChannel = null;
  destinationChannelId = null;
  selectedMessageIds = null;

  @reads("selectedMessageIds.length") selectedMessageCount;

  @computed("destinationChannelId")
  get disableMoveButton() {
    return isBlank(this.destinationChannelId);
  }

  @computed("chatChannelsManager.publicMessageChannels.[]")
  get availableChannels() {
    return this.chatChannelsManager.publicMessageChannels.rejectBy(
      "id",
      this.sourceChannel.id
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
        this.router.transitionTo(
          "chat.channel.near-message",
          "-",
          response.destination_channel_id,
          response.first_moved_message_id
        );
      })
      .catch(popupAjaxError);
  }

  @computed()
  get instructionsText() {
    return htmlSafe(
      I18n.t("chat.move_to_channel.instructions", {
        channelTitle: this.sourceChannel.escapedTitle,
        count: this.selectedMessageCount,
      })
    );
  }
}
