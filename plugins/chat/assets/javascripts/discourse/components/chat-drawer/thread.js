import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatDrawerThread extends Component {
  @service appEvents;
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;
  @service chatDrawerRouter;

  get backLink() {
    const link = {
      models: this.chat.activeChannel.routeModels,
    };

    if (this.chatDrawerRouter.previousRouteName === "chat.channel.threads") {
      link.title = "chat.return_to_threads_list";
      link.route = "chat.channel.threads";
    } else {
      link.title = "chat.return_to_list";
      link.route = "chat.channel";
    }

    return link;
  }

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
