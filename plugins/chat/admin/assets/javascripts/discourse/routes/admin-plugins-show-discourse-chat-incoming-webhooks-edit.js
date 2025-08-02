import EmberObject from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseRoute from "discourse/routes/discourse";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

export default class DiscourseChatIncomingWebhooksEdit extends DiscourseRoute {
  @service currentUser;

  async model(params) {
    if (!this.currentUser?.admin) {
      return { model: null };
    }

    try {
      const model = await ajax(
        `/admin/plugins/chat/hooks/${params.id}/edit.json`
      );

      model.webhook = EmberObject.create(model.webhook);
      model.webhook.chat_channel = ChatChannel.create(
        model.webhook.chat_channel
      );
      model.chat_channels = model.chat_channels.map((channel) =>
        ChatChannel.create(channel)
      );

      return model;
    } catch (err) {
      popupAjaxError(err);
    }
  }
}
