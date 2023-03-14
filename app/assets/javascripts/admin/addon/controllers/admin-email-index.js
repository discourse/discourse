import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { empty } from "@ember/object/computed";
import Controller from "@ember/controller";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { observes } from "discourse-common/utils/decorators";
import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";

export default class AdminEmailIndexController extends Controller {
  @service dialog;

  /**
    Is the "send test email" button disabled?

    @property sendTestEmailDisabled
  **/
  @empty("testEmailAddress") sendTestEmailDisabled;

  /**
    Clears the 'sentTestEmail' property on successful send.

    @method testEmailAddressChanged
  **/
  @observes("testEmailAddress")
  testEmailAddressChanged() {
    this.set("sentTestEmail", false);
  }

  /**
    Sends a test email to the currently entered email address

    @method sendTestEmail
  **/
  @action
  sendTestEmail() {
    this.setProperties({
      sendingEmail: true,
      sentTestEmail: false,
    });

    ajax("/admin/email/test", {
      type: "POST",
      data: { email_address: this.testEmailAddress },
    })
      .then((response) =>
        this.set("sentTestEmailMessage", response.sent_test_email_message)
      )
      .catch((e) => {
        if (e.jqXHR.responseJSON?.errors) {
          this.dialog.alert({
            message: htmlSafe(
              I18n.t("admin.email.error", {
                server_error: escapeExpression(e.jqXHR.responseJSON.errors[0]),
              })
            ),
          });
        } else {
          this.dialog.alert({ message: I18n.t("admin.email.test_error") });
        }
      })
      .finally(() => this.set("sendingEmail", false));
  }
}
