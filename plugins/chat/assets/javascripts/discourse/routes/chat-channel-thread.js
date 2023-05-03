import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatChannelThread extends DiscourseRoute {
  @service router;
  @service chatStateManager;
  @service chat;

  async model(params) {
    const channel = this.modelFor("chat.channel");

    return channel.threadsManager
      .find(channel.id, params.threadId)
      .catch((xhr) => {
        if (xhr.jqXHR.status === 404) {
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
