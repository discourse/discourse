import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const REWIND_ATTRS = ["discourse_rewind_disabled"];

export default class PreferencesRewindController extends Controller {
  subpageTitle = i18n("discourse_rewind.title");

  @action
  save() {
    this.set("saved", false);
    return this.model
      .save(REWIND_ATTRS)
      .then(() => {
        this.set("saved", true);
      })
      .catch(popupAjaxError);
  }
}
