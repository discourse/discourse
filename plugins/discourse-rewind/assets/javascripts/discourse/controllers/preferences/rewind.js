import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const REWIND_ATTRS = [
  "discourse_rewind_disabled",
  "discourse_rewind_share_publicly",
];

export default class PreferencesRewindController extends Controller {
  @service rewind;

  subpageTitle = i18n("discourse_rewind.title");

  @action
  save() {
    this.set("saved", false);
    return this.model
      .save(REWIND_ATTRS)
      .then(() => {
        this.set("saved", true);
        this.rewind.disabled = this.model.user_option.discourse_rewind_disabled;
      })
      .catch(popupAjaxError);
  }
}
