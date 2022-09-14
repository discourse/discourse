import Controller from "@ember/controller";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default Controller.extend({
  dialog: service(),

  @action
  destroy(webhook) {
    return this.dialog.yesNoConfirm({
      message: I18n.t("admin.web_hooks.delete_confirm"),
      didConfirm: () => {
        webhook
          .destroyRecord()
          .then(() => {
            this.model.removeObject(webhook);
          })
          .catch(popupAjaxError);
      },
    });
  },

  @action
  loadMore() {
    this.model.loadMore();
  },
});
