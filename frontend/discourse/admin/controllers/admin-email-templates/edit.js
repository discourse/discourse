import { cached, tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action, computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import BufferedProxy from "ember-buffered-proxy/proxy";
import { popupAjaxError } from "discourse/lib/ajax-error";
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

  @computed("buffered.body", "buffered.subject")
  get saveDisabled() {
    return (
      this.emailTemplate.body === this.buffered?.body &&
      this.emailTemplate.subject === this.buffered?.subject
    );
  }

  @computed("buffered")
  get hasMultipleSubjects() {
    if (this.buffered.getProperties("subject")["subject"]) {
      return false;
    } else {
      return this.buffered.getProperties("id")["id"];
    }
  }

  @computed("buffered")
  get hasMultipleBodyTemplates() {
    if (!isObject(this.buffered.getProperties("body")["body"])) {
      return false;
    } else {
      return this.buffered.getProperties("id")["id"];
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
}
