import Controller from "@ember/controller";
import I18n from "I18n";
import { INPUT_DELAY } from "discourse-common/config/environment";
import Permalink from "admin/models/permalink";
import bootbox from "bootbox";
import discourseDebounce from "discourse-common/lib/debounce";
import { observes } from "discourse-common/utils/decorators";
import { clipboardCopy } from "discourse/lib/utilities";

export default Controller.extend({
  loading: false,
  filter: null,

  _debouncedShow() {
    Permalink.findAll(this.filter).then((result) => {
      this.set("model", result);
      this.set("loading", false);
    });
  },

  @observes("filter")
  show() {
    discourseDebounce(this, this._debouncedShow, INPUT_DELAY);
  },

  actions: {
    recordAdded(arg) {
      this.model.unshiftObject(arg);
    },

    copyUrl(pl) {
      let linkElement = document.querySelector(`#admin-permalink-${pl.id}`);
      clipboardCopy(linkElement.textContent);
    },

    destroy(record) {
      return bootbox.confirm(
        I18n.t("admin.permalink.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        (result) => {
          if (result) {
            record.destroy().then(
              (deleted) => {
                if (deleted) {
                  this.model.removeObject(record);
                } else {
                  bootbox.alert(I18n.t("generic_error"));
                }
              },
              function () {
                bootbox.alert(I18n.t("generic_error"));
              }
            );
          }
        }
      );
    },
  },
});
