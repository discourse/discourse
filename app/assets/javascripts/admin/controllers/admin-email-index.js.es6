import { empty } from "@ember/object/computed";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { observes } from "discourse-common/utils/decorators";

export default Controller.extend({
  /**
    Is the "send test email" button disabled?

    @property sendTestEmailDisabled
  **/
  sendTestEmailDisabled: empty("testEmailAddress"),

  /**
    Clears the 'sentTestEmail' property on successful send.

    @method testEmailAddressChanged
  **/
  @observes("testEmailAddress")
  testEmailAddressChanged: function() {
    this.set("sentTestEmail", false);
  },

  actions: {
    /**
      Sends a test email to the currently entered email address

      @method sendTestEmail
    **/
    sendTestEmail: function() {
      this.setProperties({
        sendingEmail: true,
        sentTestEmail: false
      });

      ajax("/admin/email/test", {
        type: "POST",
        data: { email_address: this.testEmailAddress }
      })
        .then(response =>
          this.set("sentTestEmailMessage", response.sent_test_email_message)
        )
        .catch(e => {
          if (e.responseJSON && e.responseJSON.errors) {
            bootbox.alert(
              I18n.t("admin.email.error", {
                server_error: e.responseJSON.errors[0]
              })
            );
          } else {
            bootbox.alert(I18n.t("admin.email.test_error"));
          }
        })
        .finally(() => this.set("sendingEmail", false));
    }
  }
});
