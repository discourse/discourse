import Controller from "@ember/controller";
import discourseDebounce from "discourse/lib/debounce";
import Permalink from "admin/models/permalink";
import { observes } from "discourse-common/utils/decorators";

export default Controller.extend({
  loading: false,
  filter: null,

  @observes("filter")
  show: discourseDebounce(function() {
    Permalink.findAll(this.filter).then(result => {
      this.set("model", result);
      this.set("loading", false);
    });
  }, 250),

  actions: {
    recordAdded(arg) {
      this.model.unshiftObject(arg);
    },

    destroy: function(record) {
      return bootbox.confirm(
        I18n.t("admin.permalink.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            record.destroy().then(
              deleted => {
                if (deleted) {
                  this.model.removeObject(record);
                } else {
                  bootbox.alert(I18n.t("generic_error"));
                }
              },
              function() {
                bootbox.alert(I18n.t("generic_error"));
              }
            );
          }
        }
      );
    }
  }
});
