import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { addUniqueValuesToArray } from "discourse/lib/array-tools";

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
    const limit = 50;

    try {
      this.loading = true;
      const keys = await this.store.findAll("api-key", {
        offset: this.model.length,
        limit,
      });

      addUniqueValuesToArray(this.model.content, keys);
      if (keys.length < limit) {
        this.model.loaded = true;
      }
    } finally {
      this.loading = false;
    }
  }
}
