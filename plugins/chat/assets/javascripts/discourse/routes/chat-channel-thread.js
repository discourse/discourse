import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelThread extends DiscourseRoute {
  @service router;
  @service chatStateManager;
  @service chat;
  @service chatStagedThreadMapping;

  model(params, transition) {
    const channel = this.modelFor("chat.channel");

    return channel.threadsManager
      .find(channel.id, params.threadId)
      .catch((xhr) => {
        if (xhr.jqXHR.status === 404) {
          // This is a very special logic to attempt to reconciliate a staged thread id
          // it happens after creating a new thread and having a temp ID in the URL
          // if users presses reload at this moment, we would have a 404
          // replacing the ID in the URL sooner would also cause a reload
          const mapping = this.chatStagedThreadMapping.getMapping();
          if (mapping[params.threadId]) {
            transition.abort();
            this.router.transitionTo(
              "chat.channel.thread",
              ...[...channel.routeModels, mapping[params.threadId]]
            );
            return;
          }

          // silently ignore 404s to close in after model
          return;
        }
      });
  }

  deactivate() {
    this.#closeThread();
  }

  beforeModel() {
    this.chatStateManager.closeSidePanel();
  }

  afterModel(model, transition) {
    const channel = this.modelFor("chat.channel");

    if (!model) {
      transition.abort();
      this.router.transitionTo("chat.channel", ...channel.routeModels);
      return;
    }

    if (!channel.threadingEnabled) {
      transition.abort();
      return;
    }

    this.chat.activeChannel.activeThread = model;
    this.chatStateManager.openSidePanel();
  }

  #closeThread() {
    this.chat.activeChannel.activeThread?.messagesManager?.clearMessages();
    this.chat.activeChannel.activeThread = null;
    this.chatStateManager.closeSidePanel();
  }
}
