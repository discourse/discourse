import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminApiKeysIndexController extends Controller {
  loading = false;

  @action
  revokeKey(key) {
    key.revoke().catch(popupAjaxError);
  }

  @action
  undoRevokeKey(key) {
    key.undoRevoke().catch(popupAjaxError);
  }

  @action
  loadMore() {
    if (this.loading || this.model.loaded) {
      return;
    }

    const limit = 50;

    this.set("loading", true);
    this.store
      .findAll("api-key", { offset: this.model.length, limit })
      .then((keys) => {
        this.model.addObjects(keys);
        if (keys.length < limit) {
          this.model.set("loaded", true);
        }
      })
      .finally(() => {
        this.set("loading", false);
      });
  }
}
