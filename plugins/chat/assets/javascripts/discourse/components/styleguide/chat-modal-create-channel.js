import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ChatModalCreateChannel from "discourse/plugins/chat/discourse/components/chat/modal/create-channel";

export default class ChatStyleguideChatModalCreateChannel extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalCreateChannel);
  }
}
