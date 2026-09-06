import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

export default class ChatNewMessageRoute extends DiscourseRoute {
  @service chat;
  @service chatApi;
  @service chatChannelsManager;
  @service chatDraftsManager;
  @service currentUser;
  @service modal;
  @service router;

  async beforeModel(transition) {
    if (!this.currentUser) {
      transition.abort();
      this.router.transitionTo("chat.channels");
      return;
    }

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
    if (!message || this.#hasExistingDraft(channel)) {
      return;
    }

    const draft = ChatMessage.createDraftMessage(channel, {
      user: this.currentUser,
      message,
    });

    channel.draft = draft;
    this.chatDraftsManager.add(draft, channel.id, null, false);
  }

  #hasExistingDraft(channel) {
    return [channel.draft, this.chatDraftsManager.get(channel.id)].some(
      (draft) => draft?.message?.length > 0 || draft?.uploads?.length > 0
    );
  }

  async #findChannel({ channelId, channelSlug }) {
    await this.chat.loadChannels();

    if (channelId) {
      return this.chatChannelsManager.find(channelId);
    }

    const cachedChannel = this.chatChannelsManager.channels.find(
      (channel) => channel.slug === channelSlug
    );

    if (cachedChannel) {
      return cachedChannel;
    }

    const channels = this.chatApi.channels({ filter: channelSlug });
    await channels.load({ limit: 10 });

    return channels.items.find((channel) => channel.slug === channelSlug);
  }
}
