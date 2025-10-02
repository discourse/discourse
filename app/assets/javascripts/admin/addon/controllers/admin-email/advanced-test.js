import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

// eslint-disable-next-line ember/no-test-import-export
export default class AdminEmailAdvancedTestController extends Controller {
  email = null;
  text = null;
  elided = null;
  format = null;
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
