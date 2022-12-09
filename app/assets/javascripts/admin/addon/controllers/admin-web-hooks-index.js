import Controller, { inject as controller } from "@ember/controller";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";

export default Controller.extend({
  adminWebHooks: controller(),
  dialog: service(),
  contentTypes: alias("adminWebHooks.contentTypes"),
  defaultEventTypes: alias("adminWebHooks.defaultEventTypes"),
  deliveryStatuses: alias("adminWebHooks.deliveryStatuses"),
  eventTypes: alias("adminWebHooks.eventTypes"),
  model: alias("adminWebHooks.model"),

  @action
  destroy(webhook) {
    return this.dialog.deleteConfirm({
      message: I18n.t("admin.web_hooks.delete_confirm"),
      didConfirm: async () => {
        try {
          await webhook.destroyRecord();
          this.model.removeObject(webhook);
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  },

  @action
  loadMore() {
    this.model.loadMore();
  },
});
