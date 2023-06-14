import Component from "@glimmer/component";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { CHANNEL_STATUSES } from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ChatStyleguideChatComposer extends Component {
  @service chatChannelComposer;
  @service chatChannelPane;

  channel = fabricators.channel({ id: -999 });

  @action
  toggleDisabled() {
    if (this.channel.status === CHANNEL_STATUSES.open) {
      this.channel.status = CHANNEL_STATUSES.readOnly;
    } else {
      this.channel.status = CHANNEL_STATUSES.open;
    }
  }

  @action
  toggleSending() {
    this.chatChannelPane.sending = !this.chatChannelPane.sending;
  }

  @action
  onSendMessage() {
    this.chatChannelComposer.reset();
  }
}
