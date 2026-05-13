import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

export default class ChatNewMessageRoute extends DiscourseRoute {
  @service chat;
  @service chatChannelsManager;
  @service chatDraftsManager;
  @service currentUser;
  @service modal;
  @service router;

  async beforeModel(transition) {
    const params = this.paramsFor(this.routeName);
    const recipients = params.recipients?.split(",");
    const channelIdentifier = params.channel_id || params.channel;

    if (channelIdentifier) {
      const channel = await this.#findChannel(channelIdentifier);

      if (!channel) {
        transition.abort();
        this.router.transitionTo("chat");
        return;
      }

      this.#seedDraft(channel, params.message);
      this.router.transitionTo("chat.channel", ...channel.routeModels);
      return;
    }

    if (!recipients) {
      transition.abort();

      if (!transition.from) {
        this.router.transitionTo("chat");
        return;
      }

      this.modal.show(ChatModalNewMessage);

      return;
    }

    this.chat.upsertDmChannel({ usernames: recipients }).then((channel) => {
      this.#seedDraft(channel, params.message);
      this.router.transitionTo("chat.channel", channel.title, channel.id);
    });
  }

  #seedDraft(channel, message) {
    if (!message) {
      return;
    }

    this.chatDraftsManager.add(
      ChatMessage.createDraftMessage(channel, {
        user: this.currentUser,
        message,
      }),
      channel.id,
      null,
      false
    );
  }

  async #findChannel(identifier) {
    await this.chat.loadChannels();

    if (/^\d+$/.test(String(identifier))) {
      const byId = await this.chatChannelsManager.find(identifier, {
        fetchIfNotFound: false,
      });
      if (byId) {
        return byId;
      }
    }

    return this.chatChannelsManager.channels.find(
      (channel) => channel.slug === identifier
    );
  }
}
