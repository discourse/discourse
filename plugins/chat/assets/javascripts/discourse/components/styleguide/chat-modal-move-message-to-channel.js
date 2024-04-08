import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ChatModalMoveMessageToChannel from "discourse/plugins/chat/discourse/components/chat/modal/move-message-to-channel";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatModalMoveMessageToChannel extends Component {
  @service modal;

  channel = fabricators.channel();
  selectedMessageIds = [fabricators.message({ channel: this.channel })].mapBy(
    "id"
  );

  @action
  openModal() {
    return this.modal.show(ChatModalMoveMessageToChannel, {
      model: {
        sourceChannel: this.channel,
        selectedMessageIds: [
          fabricators.message({ channel: this.channel }),
        ].mapBy("id"),
      },
    });
  }
}
