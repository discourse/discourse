import EmailPreview from "admin/models/email-preview";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend({
  username: null,
  lastSeen: null,

  emailEmpty: Ember.computed.empty("email"),
  sendEmailDisabled: Ember.computed.or("emailEmpty", "sendingEmail"),
  showSendEmailForm: Ember.computed.notEmpty("model.html_content"),
  htmlEmpty: Ember.computed.empty("model.html_content"),

  actions: {
    refresh() {
      const model = this.get("model");

      this.set("loading", true);
      this.set("sentEmail", false);

      let username = this.get("username");
      if (!username) {
        username = this.currentUser.get("username");
        this.set("username", username);
      }

      EmailPreview.findDigest(username, this.get("lastSeen")).then(email => {
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

      EmailPreview.sendDigest(
        this.get("username"),
        this.get("lastSeen"),
        this.get("email")
      )
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
