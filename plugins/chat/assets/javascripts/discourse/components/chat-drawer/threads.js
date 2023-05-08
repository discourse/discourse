import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatDrawerThreads extends Component {
  @service appEvents;
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;

  @tracked threads;

  @action
  fetchChannelAndThreads() {
    if (!this.args.params?.channelId) {
      return;
    }

    return this.chatChannelsManager
      .find(this.args.params.channelId)
      .then((channel) => {
        this.chat.activeChannel = channel;

        channel.threadsManager
          .index(this.args.params.channelId)
          .then((threads) => {
            this.threads = threads;
          });
      });
  }
}
