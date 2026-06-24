import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";

export default class UserActivityPendingController extends Controller {
  @action
  deletePending(pending) {
    return ajax(`/review/${pending.id}`, { type: "DELETE" })
      .then(() => {
        removeValueFromArray(this.model.content, pending);
      })
      .catch(popupAjaxError);
  }
}
