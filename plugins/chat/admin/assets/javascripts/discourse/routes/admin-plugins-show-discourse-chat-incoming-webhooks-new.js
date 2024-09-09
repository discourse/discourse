import EmberObject from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

export default class DiscourseChatIncomingWebhooksNew extends DiscourseRoute {
  @service adminPluginNavManager;
  @service currentUser;

  model() {
    if (!this.currentUser?.admin) {
      return { model: null };
    }

    return ajax(`/admin/plugins/chat/hooks/new.json`).then((model) => {
      model.webhook = EmberObject.create(model.webhook);
      model.webhook.chat_channel = ChatChannel.create(
        model.webhook.chat_channel
      );
      model.chat_channels = model.chat_channels.map((channel) =>
        ChatChannel.create(channel)
      );
      return model;
    });
  }
}
