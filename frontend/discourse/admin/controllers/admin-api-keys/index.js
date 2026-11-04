import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminApiKeysIndexController extends Controller {
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
}
