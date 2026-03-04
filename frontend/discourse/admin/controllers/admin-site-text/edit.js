import { cached, tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import BufferedProxy from "ember-buffered-proxy/proxy";
import { interpolationKeysWithStatus as computeInterpolationKeysWithStatus } from "discourse/admin/lib/interpolation-keys";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminSiteTextEdit extends Controller {
  @service dialog;

  @tracked siteText;
  saved = false;
  queryParams = ["locale"];

  #activeTextarea = null;
  #lastCursorPos = null;

  @cached
  @dependentKeyCompat
  get buffered() {
    return BufferedProxy.create({
      content: this.siteText,
    });
  }

  @computed("buffered.value", "siteText.value")
  get saveDisabled() {
    return this.siteText.value === this.get("buffered.value"); // TODO (devxp) we need a buffered proxy that works with tracked properties
  }

  @computed("siteText.status")
  get isOutdated() {
    return this.siteText?.status === "outdated";
  }

  @action
  trackTextarea(event) {
    this.#activeTextarea = event.target;
  }

  @action
  saveCursorPos() {
    const textarea = this.#activeTextarea;
    if (textarea) {
      this.#lastCursorPos = {
        start: textarea.selectionStart,
        end: textarea.selectionEnd,
      };
    }
  }

  resetTextarea() {
    this.#activeTextarea = null;
    this.#lastCursorPos = null;
  }

  @action
  registerTextarea(element) {
    this.#activeTextarea = element.querySelector("textarea") ?? element;
  }

  @action
  insertInterpolationKey(key) {
    const textarea = this.#activeTextarea;
    if (!textarea) {
      return;
    }

    const token = `%{${key}}`;
    const start = this.#lastCursorPos?.start ?? textarea.value.length;
    const end = this.#lastCursorPos?.end ?? textarea.value.length;

    textarea.focus();
    textarea.setSelectionRange(start, end);
    document.execCommand("insertText", false, token);

    const newPos = textarea.selectionStart;
    this.#lastCursorPos = { start: newPos, end: newPos };
    this.buffered.set("value", textarea.value);
  }

  @action
  saveChanges() {
    const attrs = this.buffered.getProperties("value");
    attrs.locale = this.locale;

    this.siteText
      .save(attrs)
      .then(() => {
        this.buffered.applyChanges();
        this.set("saved", true);
      })
      .catch(popupAjaxError);
  }

  @action
  revertChanges() {
    this.set("saved", false);

    this.dialog.yesNoConfirm({
      message: i18n("admin.site_text.revert_confirm"),
      didConfirm: () => {
        this.siteText
          .revert(this.locale)
          .then((props) => {
            const buffered = this.buffered;
            buffered.setProperties(props);
            this.buffered.applyChanges();
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  dismissOutdated() {
    this.siteText
      .dismissOutdated(this.locale)
      .then(() => {
        this.siteText.set("status", "up_to_date");
      })
      .catch(popupAjaxError);
  }

  @computed("buffered.value", "siteText.interpolation_keys")
  get interpolationKeysWithStatus() {
    return computeInterpolationKeysWithStatus(
      this.get("buffered.value"),
      this.siteText.interpolation_keys
    );
  }
}
