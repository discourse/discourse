import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatDrawerChannel extends Component {
  @service appEvents;
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;

  @action
  fetchChannel() {
    if (!this.args.params?.channelId) {
      return;
    }

    return this.chatChannelsManager
      .find(this.args.params.channelId)
      .then((channel) => {
        this.chat.setActiveChannel(channel);
      });
  }
}
