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

    if (params.channel_id || params.channel) {
      const channel = await this.#findChannel({
        channelId: params.channel_id,
        channelSlug: params.channel,
      });

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

  async #findChannel({ channelId, channelSlug }) {
    await this.chat.loadChannels();

    if (channelId) {
      return this.chatChannelsManager.find(channelId, {
        fetchIfNotFound: false,
      });
    }

    return this.chatChannelsManager.channels.find(
      (channel) => channel.slug === channelSlug
    );
  }
}
