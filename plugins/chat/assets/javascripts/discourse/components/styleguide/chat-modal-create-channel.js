import Component from "@glimmer/component";
import ChatModalCreateChannel from "discourse/plugins/chat/discourse/components/chat/modal/create-channel";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatStyleguideChatModalCreateChannel extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalCreateChannel);
  }
}
