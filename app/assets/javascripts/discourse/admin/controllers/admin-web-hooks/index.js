import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminWebHooksIndexController extends Controller {
  @service dialog;
  @controller adminWebHooks;

  @alias("adminWebHooks.contentTypes") contentTypes;
  @alias("adminWebHooks.defaultEventTypes") defaultEventTypes;
  @alias("adminWebHooks.deliveryStatuses") deliveryStatuses;
  @alias("adminWebHooks.eventTypes") eventTypes;
  @alias("adminWebHooks.model") model;

  @action
  destroyWebhook(webhook) {
    return this.dialog.deleteConfirm({
      message: i18n("admin.web_hooks.delete_confirm"),
      didConfirm: async () => {
        try {
          await webhook.destroyRecord();
          this.model.removeObject(webhook);
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  loadMore() {
    this.model.loadMore();
  }
}
