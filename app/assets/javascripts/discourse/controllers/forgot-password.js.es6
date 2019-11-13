import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { escapeExpression } from "discourse/lib/utilities";
import { extractError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, {
  offerHelp: null,
  helpSeen: false,

  @discourseComputed("accountEmailOrUsername", "disabled")
  submitDisabled(accountEmailOrUsername, disabled) {
    return isEmpty((accountEmailOrUsername || "").trim()) || disabled;
  },

  onShow() {
    if ($.cookie("email")) {
      this.set("accountEmailOrUsername", $.cookie("email"));
    }
  },

  actions: {
    ok() {
      this.send("closeModal");
    },

    help() {
      this.setProperties({
        offerHelp: I18n.t("forgot_password.help", {
          basePath: Discourse.BaseUri
        }),
        helpSeen: true
      });
    },

    resetPassword() {
      if (this.submitDisabled) return false;
      this.set("disabled", true);

      this.clearFlash();

      ajax("/session/forgot_password", {
        data: { login: this.accountEmailOrUsername.trim() },
        type: "POST"
      })
        .then(data => {
          const accountEmailOrUsername = escapeExpression(
            this.accountEmailOrUsername
          );
          const isEmail = accountEmailOrUsername.match(/@/);
          let key = `forgot_password.complete_${
            isEmail ? "email" : "username"
          }`;
          let extraClass;

          if (data.user_found === true) {
            key += "_found";
            this.set("accountEmailOrUsername", "");
            this.set(
              "offerHelp",
              I18n.t(key, {
                email: accountEmailOrUsername,
                username: accountEmailOrUsername
              })
            );
          } else {
            if (data.user_found === false) {
              key += "_not_found";
              extraClass = "error";
            }

            this.flash(
              I18n.t(key, {
                email: accountEmailOrUsername,
                username: accountEmailOrUsername
              }),
              extraClass
            );
          }
        })
        .catch(e => {
          this.flash(extractError(e), "error");
        })
        .finally(() => {
          this.set("disabled", false);
        });

      return false;
    }
  }
});
