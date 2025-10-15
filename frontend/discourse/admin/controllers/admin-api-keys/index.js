import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminApiKeysIndexController extends Controller {
  @tracked loading = false;

  @action
  async revokeKey(key) {
    try {
      await key.revoke();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async undoRevokeKey(key) {
    try {
      await key.undoRevoke();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async loadMore() {
    if (this.loading || this.model.loaded) {
      return;
    }

    const limit = 50;

    try {
      this.loading = true;
      const keys = await this.store.findAll("api-key", {
        offset: this.model.length,
        limit,
      });

      // this.model is an instance of a ResultSet. We need to keep using `.addObjects` for now to preserve the
      // KVO-compliant behavior of the model.
      this.model.addObjects(keys);
      if (keys.length < limit) {
        this.model.set("loaded", true);
      }
    } finally {
      this.loading = false;
    }
  }
}
