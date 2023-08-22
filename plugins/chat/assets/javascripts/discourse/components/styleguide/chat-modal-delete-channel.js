import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import ChatModalDeleteChannel from "discourse/plugins/chat/discourse/components/chat/modal/delete-channel";
import Component from "@glimmer/component";

export default class ChatStyleguideChatModalDeleteChannel extends Component {
  @service modal;

  channel = fabricators.channel();

  @action
  openModal() {
    return this.modal.show(ChatModalDeleteChannel, {
      model: { channel: this.channel },
    });
  }
}
