import { inject as service } from "@ember/service";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminWebHooksShowController extends Controller {
  @service dialog;
  @service router;
  @controller adminWebHooks;

  @action
  edit() {
    return this.router.transitionTo("adminWebHooks.edit", this.model);
  }

  @action
  destroy() {
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
