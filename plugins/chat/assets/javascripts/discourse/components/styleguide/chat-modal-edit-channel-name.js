import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ChatModalEditChannelName from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-name";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatModalEditChannelName extends Component {
  @service modal;

  channel = fabricators.channel();

  @action
  openModal() {
    return this.modal.show(ChatModalEditChannelName, {
      model: this.channel,
    });
  }
}
