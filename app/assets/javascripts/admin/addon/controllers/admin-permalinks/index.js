import Controller from "@ember/controller";
import { action } from "@ember/object";
import { or } from "@ember/object/computed";
import { service } from "@ember/service";
import { observes } from "@ember-decorators/object";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import Permalink from "admin/models/permalink";

export default class AdminPermalinksIndexController extends Controller {
  @service dialog;
  @service toasts;

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
  copyUrl(pl) {
    let linkElement = document.querySelector(`#admin-permalink-${pl.id}`);
    clipboardCopy(linkElement.textContent);
    this.toasts.success({
      duration: "short",
      data: {
        message: i18n("admin.permalink.copy_success"),
      },
    });
  }

  @action
  destroyRecord(permalink) {
    this.dialog.deleteConfirm({
      title: i18n("admin.permalink.delete_confirm"),
      didConfirm: async () => {
        try {
          await this.store.destroyRecord("permalink", permalink);
          this.model.removeObject(permalink);
        } catch {
          this.dialog.alert(i18n("generic_error"));
        }
      },
    });
  }
}
