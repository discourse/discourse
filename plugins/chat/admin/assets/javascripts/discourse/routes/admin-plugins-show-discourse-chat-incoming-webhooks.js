import EmberObject from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

export default class DiscourseChatIncomingWebhooks extends DiscourseRoute {
  @service adminPluginNavManager;

  model() {
    if (!this.currentUser?.admin) {
      return { model: null };
    }

    return ajax("/admin/plugins/chat/hooks.json").then((model) => {
      model.chat_channels = model.chat_channels.map((channel) =>
        ChatChannel.create(channel)
      );

      model.incoming_chat_webhooks = model.incoming_chat_webhooks.map(
        (webhook) => {
          webhook.chat_channel = ChatChannel.create(webhook.chat_channel);
          return EmberObject.create(webhook);
        }
      );

      return model;
    });
  }
}
