import Component from "@ember/component";
import { inject as service } from "@ember/service";
import { action, computed } from "@ember/object";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import cookie from "discourse/lib/cookie";
import { escapeExpression } from "discourse/lib/utilities";
import { extractError } from "discourse/lib/ajax-error";
import getURL from "discourse-common/lib/get-url";
import { isEmpty } from "@ember/utils";
import { htmlSafe } from "@ember/template";

export default class ForgotPassword extends Component {
  @service siteSettings;

  emailOrUsername = this.args.model.emailOrUsername;
  disabled = false;
  helpSeen = false;
  offerHelp;
  flash;

  @computed("emailOrUsername", "disabled")
  get submitDisabled() {
    if (this.disabled) {
      return true;
    }

    if (this.siteSettings.hide_email_address_taken) {
      return !(this.emailOrUsername || "").includes("@");
    } else {
      return isEmpty((this.emailOrUsername || "").trim());
    }
  }

  onShow() {
    if (cookie("email")) {
      this.set("emailOrUsername", cookie("email"));
    }
  }

  @action
  ok() {
    this.args.closeModal();
  }

  @action
  help() {
    this.setProperties({
      offerHelp: I18n.t("forgot_password.help", {
        basePath: getURL(""),
      }),
      helpSeen: true,
    });
  }

  @action
  async resetPassword() {
    if (this.submitDisabled) {
      return false;
    }

    this.set("disabled", true);

    this.set("flash", null);

    try {
      const data = await ajax("/session/forgot_password", {
        data: { login: this.emailOrUsername.trim() },
        type: "POST",
      });

      const emailOrUsername = escapeExpression(this.emailOrUsername);

      let key = "forgot_password.complete";
      key += emailOrUsername.match(/@/) ? "_email" : "_username";

      if (data.user_found === false) {
        key += "_not_found";

        this.set(
          "flash",
          htmlSafe(
            I18n.t(key, {
              email: emailOrUsername,
              username: emailOrUsername,
            })
          )
        );
      } else {
        key += data.user_found ? "_found" : "";

        this.set("emailOrUsername", "");
        this.set(
          "offerHelp",
          I18n.t(key, {
            email: emailOrUsername,
            username: emailOrUsername,
          })
        );
        this.set("helpSeen", !data.user_found);
      }
    } catch (error) {
      this.set("flash", extractError(error));
    } finally {
      this.set("disabled", false);
    }

    return false;
  }
}
