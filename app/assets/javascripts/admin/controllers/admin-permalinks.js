import I18n from "I18n";
import Controller from "@ember/controller";
import discourseDebounce from "discourse/lib/debounce";
import Permalink from "admin/models/permalink";
import { observes } from "discourse-common/utils/decorators";
import { INPUT_DELAY } from "discourse-common/config/environment";

export default Controller.extend({
  loading: false,
  filter: null,

  @observes("filter")
  show: discourseDebounce(function() {
    Permalink.findAll(this.filter).then(result => {
      this.set("model", result);
      this.set("loading", false);
    });
  }, INPUT_DELAY),

  actions: {
    recordAdded(arg) {
      this.model.unshiftObject(arg);
    },

    copyUrl(pl) {
      let linkElement = document.querySelector(`#admin-permalink-${pl.id}`);
      let textArea = document.createElement("textarea");
      textArea.value = linkElement.textContent;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand("Copy");
      textArea.remove();
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
