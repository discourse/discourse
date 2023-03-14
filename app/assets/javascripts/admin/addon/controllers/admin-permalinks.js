import Controller from "@ember/controller";
import I18n from "I18n";
import { INPUT_DELAY } from "discourse-common/config/environment";
import Permalink from "admin/models/permalink";
import discourseDebounce from "discourse-common/lib/debounce";
import { observes } from "discourse-common/utils/decorators";
import { clipboardCopy } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import { or } from "@ember/object/computed";

export default Controller.extend({
  dialog: service(),
  loading: false,
  filter: null,
  showSearch: or("model.length", "filter"),

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

    destroyRecord(record) {
      return this.dialog.yesNoConfirm({
        message: I18n.t("admin.permalink.delete_confirm"),
        didConfirm: () => {
          return record.destroy().then(
            (deleted) => {
              if (deleted) {
                this.model.removeObject(record);
              } else {
                this.dialog.alert(I18n.t("generic_error"));
              }
            },
            function () {
              this.dialog.alert(I18n.t("generic_error"));
            }
          );
        },
      });
    },
  },
});
