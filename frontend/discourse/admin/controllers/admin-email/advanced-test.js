import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminEmailAdvancedTestController extends Controller {
  /** @type {string | null} */
  email = null;

  /** @type {string | null} */
  text = null;

  /** @type {string | null} */
  elided = null;

  /** @type {1 | 2 | null} */
  format = null;

  /** @type {boolean | null} */
  loading = null;

  @action
  run() {
    this.set("loading", true);

    ajax("/admin/email/advanced-test", {
      type: "POST",
      data: { email: this.email },
    })
      .then((data) => {
        this.setProperties({
          text: data.text,
          elided: data.elided,
          format: data.format,
        });
      })
      .catch(popupAjaxError)
      .finally(() => this.set("loading", false));
  }
}
