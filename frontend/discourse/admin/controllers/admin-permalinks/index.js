import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { observes } from "@ember-decorators/object";
import Permalink from "discourse/admin/models/permalink";
import { removeValueFromArray } from "discourse/lib/array-tools";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { trackedArray } from "discourse/lib/tracked-tools";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class AdminPermalinksIndexController extends Controller {
  @service dialog;
  @service toasts;

  @tracked loading = false;
  @tracked filter = null;
  @trackedArray model;

  get showSearch() {
    return !!(this.model.length || this.filter);
  }

  @observes("filter")
  show() {
    discourseDebounce(this, this.#debouncedShow, INPUT_DELAY);
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
          removeValueFromArray(this.model, permalink);
        } catch {
          this.dialog.alert(i18n("generic_error"));
        }
      },
    });
  }

  async #debouncedShow() {
    this.loading = true;

    try {
      this.model = await Permalink.findAll(this.filter);
    } finally {
      this.loading = false;
    }
  }
}
