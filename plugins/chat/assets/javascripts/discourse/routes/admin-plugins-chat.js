import DiscourseRoute from "discourse/routes/discourse";
import EmberObject from "@ember/object";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsChatRoute extends DiscourseRoute {
  model() {
    if (!this.currentUser?.admin) {
      return { model: null };
    }

    return ajax("/admin/plugins/chat.json").then((model) => {
      model.incoming_chat_webhooks = model.incoming_chat_webhooks.map(
        (webhook) => EmberObject.create(webhook)
      );

      model.chat_channels = model.chat_channels.map((channel) => {
        return ChatChannel.create(channel);
      });

      return model;
    });
  }
}
