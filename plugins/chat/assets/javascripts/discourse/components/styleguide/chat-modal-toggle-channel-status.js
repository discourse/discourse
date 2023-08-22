import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import Component from "@glimmer/component";
import ChatModalToggleChannelStatus from "discourse/plugins/chat/discourse/components/chat/modal/toggle-channel-status";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatStyleguideChatModalToggleChannelStatus extends Component {
  @service modal;

  @action
  openModal() {
    return this.modal.show(ChatModalToggleChannelStatus, {
      model: fabricators.channel(),
    });
  }
}
