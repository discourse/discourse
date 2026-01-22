import { cached, tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import BufferedProxy from "ember-buffered-proxy/proxy";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { isObject } from "discourse/lib/object";
import { i18n } from "discourse-i18n";

export default class AdminEmailTemplatesEditController extends Controller {
  @service dialog;
  @controller adminEmailTemplates;

  @tracked emailTemplate = null;
  saved = false;

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
    if (!keys) {
      return [];
    }
    const usedKeys = new Set();
    const content = `${subject || ""} ${body || ""}`;
    const matches = content.match(/%\{(\w+)\}/g) || [];
    matches.forEach((m) => usedKeys.add(m.slice(2, -1)));
    return keys.map((key) => ({ key, isUsed: usedKeys.has(key) }));
  }
}
