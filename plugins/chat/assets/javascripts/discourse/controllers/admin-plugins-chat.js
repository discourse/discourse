import Controller from "@ember/controller";
import EmberObject, { action, computed } from "@ember/object";
import I18n from "I18n";
import { and } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";

export default class AdminPluginsChatController extends Controller {
  @service dialog;
  queryParams = { selectedWebhookId: "id" };

  loading = false;
  creatingNew = false;
  newWebhookName = "";
  newWebhookChannelId = null;
  emojiPickerIsActive = false;

  @and("newWebhookName", "newWebhookChannelId") nameAndChannelValid;

  @computed("model.incoming_chat_webhooks.@each.updated_at")
  get sortedWebhooks() {
    return (
      this.model.incoming_chat_webhooks?.sortBy("updated_at").reverse() || []
    );
  }

  @computed("selectedWebhookId")
  get selectedWebhook() {
    if (!this.selectedWebhookId) {
      return;
    }

    const id = parseInt(this.selectedWebhookId, 10);
    return this.model.incoming_chat_webhooks.findBy("id", id);
  }

  @computed("selectedWebhook.name", "selectedWebhook.chat_channel.id")
  get saveEditDisabled() {
    return !this.selectedWebhook.name || !this.selectedWebhook.chat_channel.id;
  }

  @action
  createNewWebhook() {
    if (this.loading) {
      return;
    }

    this.set("loading", true);
    const data = {
      name: this.newWebhookName,
      chat_channel_id: this.newWebhookChannelId,
    };

    return ajax("/admin/plugins/chat/hooks", { data, type: "POST" })
      .then((webhook) => {
        const newWebhook = EmberObject.create(webhook);
        this.set(
          "model.incoming_chat_webhooks",
          [newWebhook].concat(this.model.incoming_chat_webhooks)
        );
        this.resetNewWebhook();
        this.setProperties({
          loading: false,
          selectedWebhookId: newWebhook.id,
        });
      })
      .catch(popupAjaxError);
  }

  @action
  resetNewWebhook() {
    this.setProperties({
      creatingNew: false,
      newWebhookName: "",
      newWebhookChannelId: null,
    });
  }

  @action
  destroyWebhook(webhook) {
    this.dialog.deleteConfirm({
      message: I18n.t("chat.incoming_webhooks.confirm_destroy"),
      didConfirm: () => {
        this.set("loading", true);
        return ajax(`/admin/plugins/chat/hooks/${webhook.id}`, {
          type: "DELETE",
        })
          .then(() => {
            this.model.incoming_chat_webhooks.removeObject(webhook);
            this.set("loading", false);
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  emojiSelected(emoji) {
    this.selectedWebhook.set("emoji", `:${emoji}:`);
    return this.set("emojiPickerIsActive", false);
  }

  @action
  saveEdit() {
    this.set("loading", true);
    const data = {
      name: this.selectedWebhook.name,
      chat_channel_id: this.selectedWebhook.chat_channel.id,
      description: this.selectedWebhook.description,
      emoji: this.selectedWebhook.emoji,
      username: this.selectedWebhook.username,
    };
    return ajax(`/admin/plugins/chat/hooks/${this.selectedWebhook.id}`, {
      data,
      type: "PUT",
    })
      .then(() => {
        this.selectedWebhook.set("updated_at", new Date());
        this.setProperties({
          loading: false,
          selectedWebhookId: null,
        });
      })
      .catch(popupAjaxError);
  }

  @action
  changeChatChannel(chatChannelId) {
    this.selectedWebhook.set(
      "chat_channel",
      this.model.chat_channels.findBy("id", chatChannelId)
    );
  }
}
