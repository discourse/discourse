import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelThread extends DiscourseRoute {
  @service router;
  @service chatStateManager;
  @service chat;
  @service chatStagedThreadMapping;
  @service chatChannelThreadPane;

  model(params, transition) {
    const channel = this.modelFor("chat.channel");

    return channel.threadsManager
      .find(channel.id, params.threadId)
      .catch(() => {
        transition.abort();
        this.router.transitionTo("chat.channel", ...channel.routeModels);
        return;
      });
  }

  deactivate() {
    this.chatChannelThreadPane.close();
  }

  beforeModel(transition) {
    const channel = this.modelFor("chat.channel");

    if (!channel.threadingEnabled) {
      transition.abort();
      this.router.transitionTo("chat.channel", ...channel.routeModels);
      return;
    }

    // This is a very special logic to attempt to reconciliate a staged thread id
    // it happens after creating a new thread and having a temp ID in the URL
    // if users presses reload at this moment, we would have a 404
    // replacing the ID in the URL sooner would also cause a reload
    const params = this.paramsFor("chat.channel.thread");
    const threadId = params.threadId;

    if (threadId?.startsWith("staged-thread-")) {
      const mapping = this.chatStagedThreadMapping.getMapping();

      if (mapping[threadId]) {
        transition.abort();

        this.router.transitionTo(
          "chat.channel.thread",
          ...[...channel.routeModels, mapping[threadId]]
        );
        return;
      }
    }
  }

  afterModel(model) {
    this.chatChannelThreadPane.open(model);
  }
}
