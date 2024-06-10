import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";

export default class AdminWebHooksShowController extends Controller {
  @service dialog;
  @service router;
  @controller adminWebHooks;
  @tracked status;

  queryParams = ["status"];

  @action
  edit() {
    return this.router.transitionTo("adminWebHooks.edit", this.model);
  }

  @action
  destroyWebhook() {
    return this.dialog.deleteConfirm({
      message: I18n.t("admin.web_hooks.delete_confirm"),
      didConfirm: async () => {
        try {
          await this.model.destroyRecord();
          this.adminWebHooks.model.removeObject(this.model);
          this.router.transitionTo("adminWebHooks");
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }
}
