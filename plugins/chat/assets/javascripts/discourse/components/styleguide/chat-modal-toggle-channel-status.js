import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ChatModalToggleChannelStatus from "discourse/plugins/chat/discourse/components/chat/modal/toggle-channel-status";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

export default class ChatStyleguideChatModalToggleChannelStatus extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalToggleChannelStatus, {
      model: fabricators.channel(),
    });
  }
}
