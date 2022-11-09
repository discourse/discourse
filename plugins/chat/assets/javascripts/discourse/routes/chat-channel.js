import DiscourseRoute from "discourse/routes/discourse";
import Promise from "rsvp";
import EmberObject, { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";

export default class ChatChannelRoute extends DiscourseRoute {
  @service chat;
  @service fullPageChat;
  @service chatPreferredMode;

  async model(params) {
    let [chatChannel, channels] = await Promise.all([
      this.getChannel(params.channelId),
      this.chat.getChannels(),
    ]);

    return EmberObject.create({
      chatChannel,
      channels,
    });
  }

  async getChannel(id) {
    let channel = await this.chat.getChannelBy("id", id);
    if (!channel || this.forceRefetchChannel) {
      channel = await this.getChannelFromServer(id);
    }
    return channel;
  }

  async getChannelFromServer(id) {
    return ajax(`/chat/chat_channels/${id}`)
      .then((response) => ChatChannel.create(response))
      .catch(() => this.replaceWith("/404"));
  }

  afterModel(model) {
    this.appEvents.trigger("chat:navigated-to-full-page");
    this.chat.setActiveChannel(model?.chatChannel);

    const queryParams = this.paramsFor(this.routeName);
    const slug = slugifyChannel(model.chatChannel);
    if (queryParams?.channelTitle !== slug) {
      this.replaceWith("chat.channel.index", model.chatChannel.id, slug);
    }
  }

  setupController(controller) {
    super.setupController(...arguments);

    if (controller.messageId) {
      this.chat.set("messageId", controller.messageId);
      this.controller.set("messageId", null);
    }
  }

  @action
  refreshModel(forceRefetchChannel = false) {
    this.forceRefetchChannel = forceRefetchChannel;
    this.refresh();
  }
}
