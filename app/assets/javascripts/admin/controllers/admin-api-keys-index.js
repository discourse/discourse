import { popupAjaxError } from "discourse/lib/ajax-error";
import Controller from "@ember/controller";

export default Controller.extend({
  actions: {
    revokeKey(key) {
      key.revoke().catch(popupAjaxError);
    },

    undoRevokeKey(key) {
      key.undoRevoke().catch(popupAjaxError);
    }
  }
});
