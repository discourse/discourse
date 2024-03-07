import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ChatModalDeleteChannel from "discourse/plugins/chat/discourse/components/chat/modal/delete-channel";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

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
