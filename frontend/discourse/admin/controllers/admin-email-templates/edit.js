import { cached, tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import BufferedProxy from "ember-buffered-proxy/proxy";
import { interpolationKeysWithStatus as computeInterpolationKeysWithStatus } from "discourse/admin/lib/interpolation-keys";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { isObject } from "discourse/lib/object";
import { i18n } from "discourse-i18n";

export default class AdminEmailTemplatesEditController extends Controller {
  @service dialog;
  @controller adminEmailTemplates;

  @tracked emailTemplate = null;
  saved = false;

  #activeTextarea = null;
  #lastCursorPos = null;

  @cached
  @dependentKeyCompat
  get buffered() {
    return BufferedProxy.create({
      content: this.emailTemplate,
    });
  }

  @discourseComputed("buffered.body", "buffered.subject")
  saveDisabled(body, subject) {
    return (
      this.emailTemplate.body === body && this.emailTemplate.subject === subject
    );
  }

  @discourseComputed("buffered")
  hasMultipleSubjects(buffered) {
    if (buffered.getProperties("subject")["subject"]) {
      return false;
    } else {
      return buffered.getProperties("id")["id"];
    }
  }

  @discourseComputed("buffered")
  hasMultipleBodyTemplates(buffered) {
    if (!isObject(buffered.getProperties("body")["body"])) {
      return false;
    } else {
      return buffered.getProperties("id")["id"];
    }
  }

  @action
  trackTextarea(event) {
    const target = event.target;
    if (target.tagName === "TEXTAREA" || target.tagName === "INPUT") {
      this.#activeTextarea = target;
    }
  }

  @action
  saveCursorPos(event) {
    const target = event.target;
    if (target.tagName === "TEXTAREA" || target.tagName === "INPUT") {
      this.#lastCursorPos = {
        start: target.selectionStart,
        end: target.selectionEnd,
      };
    }
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

    const field = textarea.tagName === "INPUT" ? "subject" : "body";
    this.buffered.set(field, textarea.value);
  }

  @action
  saveChanges() {
    this.set("saved", false);
    const buffered = this.buffered;
    this.emailTemplate
      .save(buffered.getProperties("subject", "body"))
      .then(() => {
        this.set("saved", true);
      })
      .catch(popupAjaxError);
  }

  @action
  revertChanges() {
    this.set("saved", false);

    this.dialog.yesNoConfirm({
      title: i18n("admin.customize.email_templates.revert_confirm"),
      didConfirm: () => {
        return this.emailTemplate
          .revert()
          .then((props) => {
            const buffered = this.buffered;
            buffered.setProperties(props);
            this.buffered.applyChanges();
          })
          .catch(popupAjaxError);
      },
    });
  }

  @discourseComputed(
    "buffered.subject",
    "buffered.body",
    "emailTemplate.interpolation_keys"
  )
  interpolationKeysWithStatus(subject, body, keys) {
    return computeInterpolationKeysWithStatus(
      `${subject || ""} ${body || ""}`,
      keys
    );
  }
}
