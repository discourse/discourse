import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import Component from "@glimmer/component";
import ChatModalChannelSummary from "discourse/plugins/chat/discourse/components/chat/modal/channel-summary";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatStyleguideChatModalChannelSummary extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalChannelSummary, {
      model: { channelId: fabricators.channel().id },
    });
  }
}
