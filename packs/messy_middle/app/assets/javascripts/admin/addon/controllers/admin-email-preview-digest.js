import { inject as service } from "@ember/service";
import { empty, notEmpty, or } from "@ember/object/computed";
import Controller from "@ember/controller";
import EmailPreview from "admin/models/email-preview";
import { action, get } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminEmailPreviewDigestController extends Controller {
  @service dialog;

  username = null;
  lastSeen = null;

  @empty("email") emailEmpty;
  @or("emailEmpty", "sendingEmail") sendEmailDisabled;
  @notEmpty("model.html_content") showSendEmailForm;
  @empty("model.html_content") htmlEmpty;

  @action
  toggleShowHtml(event) {
    event?.preventDefault();
    this.toggleProperty("showHtml");
  }

  @action
  updateUsername(selected) {
    this.set("username", get(selected, "firstObject"));
  }

  @action
  refresh() {
    const model = this.model;

    this.set("loading", true);
    this.set("sentEmail", false);

    let username = this.username;
    if (!username) {
      username = this.currentUser.get("username");
      this.set("username", username);
    }

    EmailPreview.findDigest(username, this.lastSeen).then((email) => {
      model.setProperties(email.getProperties("html_content", "text_content"));
      this.set("loading", false);
    });
  }

  @action
  sendEmail() {
    this.set("sendingEmail", true);
    this.set("sentEmail", false);

    EmailPreview.sendDigest(this.username, this.lastSeen, this.email)
      .then((result) => {
        if (result.errors) {
          this.dialog.alert(result.errors);
        } else {
          this.set("sentEmail", true);
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.set("sendingEmail", false);
      });
  }
}
