import Component from "@glimmer/component";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ChatModalChannelSummary from "discourse/plugins/chat/discourse/components/chat/modal/channel-summary";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatModalChannelSummary extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalChannelSummary, {
      model: { channelId: new ChatFabricators(getOwner(this)).channel().id },
    });
  }
}
