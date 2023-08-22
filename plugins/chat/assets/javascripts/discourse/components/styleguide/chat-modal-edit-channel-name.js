import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import ChatModalEditChannelName from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-name";
import Component from "@glimmer/component";

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
