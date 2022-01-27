import Controller from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import cookie from "discourse/lib/cookie";
import discourseComputed from "discourse-common/utils/decorators";
import { escapeExpression } from "discourse/lib/utilities";
import { extractError } from "discourse/lib/ajax-error";
import getURL from "discourse-common/lib/get-url";
import { isEmpty } from "@ember/utils";

export default Controller.extend(ModalFunctionality, {
  offerHelp: null,
  helpSeen: false,

  @discourseComputed("accountEmailOrUsername", "disabled")
  submitDisabled(accountEmailOrUsername, disabled) {
    if (disabled) {
      return true;
    }

    if (this.siteSettings.hide_email_address_taken) {
      return (accountEmailOrUsername || "").indexOf("@") === -1;
    } else {
      return isEmpty((accountEmailOrUsername || "").trim());
    }
  },

  onShow() {
    if (cookie("email")) {
      this.set("accountEmailOrUsername", cookie("email"));
    }
  },

  actions: {
    ok() {
      this.send("closeModal");
    },

    help() {
      this.setProperties({
        offerHelp: I18n.t("forgot_password.help", {
          basePath: getURL(""),
        }),
        helpSeen: true,
      });
    },

    resetPassword() {
      if (this.submitDisabled) {
        return false;
      }
      this.set("disabled", true);

      this.clearFlash();

      ajax("/session/forgot_password", {
        data: { login: this.accountEmailOrUsername.trim() },
        type: "POST",
      })
        .then((data) => {
          const accountEmailOrUsername = escapeExpression(
            this.accountEmailOrUsername
          );

          let key = "forgot_password.complete";
          key += accountEmailOrUsername.match(/@/) ? "_email" : "_username";

          if (data.user_found === false) {
            key += "_not_found";

            this.flash(
              I18n.t(key, {
                email: accountEmailOrUsername,
                username: accountEmailOrUsername,
              }),
              "error"
            );
          } else {
            key += data.user_found ? "_found" : "";

            this.set("accountEmailOrUsername", "");
            this.set(
              "offerHelp",
              I18n.t(key, {
                email: accountEmailOrUsername,
                username: accountEmailOrUsername,
              })
            );
            this.set("helpSeen", !data.user_found);
          }
        })
        .catch((e) => {
          this.flash(extractError(e), "error");
        })
        .finally(() => {
          this.set("disabled", false);
        });

      return false;
    },
  },
});
