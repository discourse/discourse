import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ChatModalEditChannelName from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-name";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatModalEditChannelName extends Component {
  @service modal;

  channel = new ChatFabricators(getOwner(this)).channel();

  @action
  openModal() {
    return this.modal.show(ChatModalEditChannelName, {
      model: this.channel,
    });
  }
}
