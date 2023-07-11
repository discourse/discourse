import Component from "@glimmer/component";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatStyleguideChatModalNewMessage extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalNewMessage);
  }
}
