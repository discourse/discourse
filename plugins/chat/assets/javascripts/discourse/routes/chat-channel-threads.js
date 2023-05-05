import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelThreads extends DiscourseRoute {
  @service router;
  @service chatStateManager;
  @service chat;
  @service chatChannelThreadIndexPane;

  model() {
    const channel = this.modelFor("chat.channel");
    return channel.threadsManager.index(channel.id);
  }

  deactivate() {
    this.chatChannelThreadIndexPane.close();
  }

  beforeModel(transition) {
    const channel = this.modelFor("chat.channel");

    if (!channel.threadingEnabled) {
      transition.abort();
      this.router.transitionTo("chat.channel", ...channel.routeModels);
      return;
    }
  }

  afterModel() {
    this.chatChannelThreadIndexPane.open();
  }
}
