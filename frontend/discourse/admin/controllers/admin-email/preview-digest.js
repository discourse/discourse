import Controller from "@ember/controller";
import { action, computed, get } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import EmailPreview from "discourse/admin/models/email-preview";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminEmailPreviewDigestController extends Controller {
  @service dialog;

  username = null;
  lastSeen = null;

  @computed("email.length")
  get emailEmpty() {
    return isEmpty(this.email);
  }

  @computed("emailEmpty", "sendingEmail")
  get sendEmailDisabled() {
    return this.emailEmpty || this.sendingEmail;
  }

  @computed("model.html_content.length")
  get showSendEmailForm() {
    return !isEmpty(this.model?.html_content);
  }

  @computed("model.html_content.length")
  get htmlEmpty() {
    return isEmpty(this.model?.html_content);
  }

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
