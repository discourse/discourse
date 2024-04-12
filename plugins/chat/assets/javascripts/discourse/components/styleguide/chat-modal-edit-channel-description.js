import Component from "@glimmer/component";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ChatModalEditChannelDescription from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-description";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatModalEditChannelDescription extends Component {
  @service modal;

  channel = new ChatFabricators(getOwner(this)).channel();

  @action
  openModal() {
    return this.modal.show(ChatModalEditChannelDescription, {
      model: this.channel,
    });
  }
}
