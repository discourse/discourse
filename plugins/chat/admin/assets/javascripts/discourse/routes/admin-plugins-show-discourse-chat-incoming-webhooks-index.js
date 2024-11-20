import EmberObject from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from 'discourse-i18n';
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

export default class DiscourseChatIncomingWebhooksIndex extends DiscourseRoute {
  @service currentUser;

  async model() {
    if (!this.currentUser?.admin) {
      return { model: null };
    }

    try {
      const model = await ajax("/admin/plugins/chat/hooks.json");

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
    } catch (err) {
      popupAjaxError(err);
    }
  }

  titleToken() {
    return i18n("chat.incoming_webhooks.title");
  }
}
