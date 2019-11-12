import { empty, or, notEmpty } from "@ember/object/computed";
import Controller from "@ember/controller";
import EmailPreview from "admin/models/email-preview";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  username: null,
  lastSeen: null,

  emailEmpty: empty("email"),
  sendEmailDisabled: or("emailEmpty", "sendingEmail"),
  showSendEmailForm: notEmpty("model.html_content"),
  htmlEmpty: empty("model.html_content"),

  actions: {
    refresh() {
      const model = this.model;

      this.set("loading", true);
      this.set("sentEmail", false);

      let username = this.username;
      if (!username) {
        username = this.currentUser.get("username");
        this.set("username", username);
      }

      EmailPreview.findDigest(username, this.lastSeen).then(email => {
        model.setProperties(
          email.getProperties("html_content", "text_content")
        );
        this.set("loading", false);
      });
    },

    toggleShowHtml() {
      this.toggleProperty("showHtml");
    },

    sendEmail() {
      this.set("sendingEmail", true);
      this.set("sentEmail", false);

      EmailPreview.sendDigest(this.username, this.lastSeen, this.email)
        .then(result => {
          if (result.errors) {
            bootbox.alert(result.errors);
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
});
