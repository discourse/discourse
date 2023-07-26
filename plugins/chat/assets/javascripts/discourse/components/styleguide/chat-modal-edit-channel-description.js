import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import ChatModalEditChannelDescription from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-description";
import Component from "@glimmer/component";

export default class ChatStyleguideChatModalEditChannelDescription extends Component {
  @service modal;

  channel = fabricators.channel();

  @action
  openModal() {
    return this.modal.show(ChatModalEditChannelDescription, {
      model: this.channel,
    });
  }
}
