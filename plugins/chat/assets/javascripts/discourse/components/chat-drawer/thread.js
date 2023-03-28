import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatDrawerThread extends Component {
  @service appEvents;
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;

  @action
  fetchChannelAndThread() {
    if (!this.args.params?.channelId || !this.args.params?.threadId) {
      return;
    }

    return this.chatChannelsManager
      .find(this.args.params.channelId)
      .then((channel) => {
        this.chat.activeChannel = channel;

        channel.threadsManager
          .find(channel.id, this.args.params.threadId)
          .then((thread) => {
            this.chat.activeChannel.activeThread = thread;
          });
      });
  }
}
