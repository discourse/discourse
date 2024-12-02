import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class AdminCustomizeEmailTemplatesEditController extends Controller.extend(
  bufferedProperty("emailTemplate")
) {
  @service dialog;
  @controller adminCustomizeEmailTemplates;

  emailTemplate = null;
  saved = false;

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
            this.commitBuffer();
          })
          .catch(popupAjaxError);
      },
    });
  }
}
