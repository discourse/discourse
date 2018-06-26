import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend({
  actions: {
    destroy(webhook) {
      return bootbox.confirm(
        I18n.t("admin.web_hooks.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            webhook
              .destroyRecord()
              .then(() => {
                this.get("model").removeObject(webhook);
              })
              .catch(popupAjaxError);
          }
        }
      );
    },

    loadMore() {
      this.get("model").loadMore();
    }
  }
});
