import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { or } from "@ember/object/computed";
import Controller from "@ember/controller";
import I18n from "I18n";
import { INPUT_DELAY } from "discourse-common/config/environment";
import Permalink from "admin/models/permalink";
import discourseDebounce from "discourse-common/lib/debounce";
import { observes } from "@ember-decorators/object";
import { clipboardCopy } from "discourse/lib/utilities";

export default class AdminPermalinksController extends Controller {
  @service dialog;

  loading = false;
  filter = null;

  @or("model.length", "filter") showSearch;

  _debouncedShow() {
    Permalink.findAll(this.filter).then((result) => {
      this.set("model", result);
      this.set("loading", false);
    });
  }

  @observes("filter")
  show() {
    discourseDebounce(this, this._debouncedShow, INPUT_DELAY);
  }

  @action
  recordAdded(arg) {
    this.model.unshiftObject(arg);
  }

  @action
  copyUrl(pl) {
    let linkElement = document.querySelector(`#admin-permalink-${pl.id}`);
    clipboardCopy(linkElement.textContent);
  }

  @action
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
  }
}
