import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

export default class ChatChannelPins extends DiscourseRoute {
  @service chatStateManager;
  @service chat;
  @service chatApi;

  model() {
    const channel = this.modelFor("chat.channel");
    return this.chatApi.pinnedMessages(channel.id);
  }

  setupController(controller, model) {
    const channel = this.modelFor("chat.channel");
    const pinnedMessages = model.pinned_messages.map((pin) => {
      const message = ChatMessage.create(channel, pin.message);
      message.channel = channel;
      return { ...pin, message };
    });
    controller.set("pinnedMessages", pinnedMessages);
    controller.set("channel", channel);

    if (model.membership) {
      channel.currentUserMembership.hasUnseenPins =
        model.membership.has_unseen_pins;
      channel.currentUserMembership.lastViewedPinsAt =
        model.membership.last_viewed_pins_at;
    }
  }

  @action
  activate() {
    this.chat.activeMessage = null;
    this.chatStateManager.openSidePanel();
  }

  @action
  deactivate() {
    const channel = this.modelFor("chat.channel");

    // Update timestamp both locally and on backend when leaving pins view
    if (channel.currentUserMembership) {
      channel.currentUserMembership.lastViewedPinsAt = new Date();
      channel.currentUserMembership.hasUnseenPins = false;

      // Persist to backend so it survives page reloads
      this.chatApi.markPinsAsRead(channel.id);
    }

    this.chatStateManager.closeSidePanel();
  }
}
