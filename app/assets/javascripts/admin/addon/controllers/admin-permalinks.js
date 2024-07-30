import Controller from "@ember/controller";
import { action } from "@ember/object";
import { or } from "@ember/object/computed";
import { service } from "@ember/service";
import { observes } from "@ember-decorators/object";
import { clipboardCopy } from "discourse/lib/utilities";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import I18n from "discourse-i18n";
import Permalink from "admin/models/permalink";

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
