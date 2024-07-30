import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ChatModalArchiveChannel from "discourse/plugins/chat/discourse/components/chat/modal/archive-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatModalArchiveChannel extends Component {
  @service modal;

  channel = new ChatFabricators(getOwner(this)).channel();

  @action
  openModal() {
    return this.modal.show(ChatModalArchiveChannel, {
      model: {
        channel: this.channel,
      },
    });
  }
}
