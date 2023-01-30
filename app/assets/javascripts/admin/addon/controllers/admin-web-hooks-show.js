import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";

export default Controller.extend({
  adminWebHooks: controller(),
  dialog: service(),
  router: service(),

  @action
  edit() {
    return this.router.transitionTo("adminWebHooks.edit", this.model);
  },

  @action
  destroy() {
    return this.dialog.deleteConfirm({
      message: I18n.t("admin.web_hooks.delete_confirm"),
      didConfirm: async () => {
        try {
          await this.model.destroyRecord();
          this.adminWebHooks.model.removeObject(this.model);
          this.transitionToRoute("adminWebHooks");
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  },
});
