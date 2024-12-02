import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import cookie from "discourse/lib/cookie";
import { escapeExpression } from "discourse/lib/utilities";
import getURL from "discourse-common/lib/get-url";
import { i18n } from "discourse-i18n";

export default class ForgotPassword extends Component {
  @service siteSettings;

  @tracked
  emailOrUsername = cookie("email") || this.args.model?.emailOrUsername || "";
  @tracked disabled = false;
  @tracked helpSeen = false;
  @tracked offerHelp;
  @tracked flash;

  get submitDisabled() {
    if (this.disabled) {
      return true;
    } else if (this.siteSettings.hide_email_address_taken) {
      return !this.emailOrUsername.includes("@");
    } else {
      return isEmpty(this.emailOrUsername.trim());
    }
  }

  @action
  updateEmailOrUsername(event) {
    this.emailOrUsername = event.target.value;
  }

  @action
  help() {
    this.offerHelp = i18n("forgot_password.help", { basePath: getURL("") });
    this.helpSeen = true;
  }

  @action
  async resetPassword() {
    if (this.submitDisabled) {
      return false;
    }

    this.disabled = true;
    this.flash = null;

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

        this.flash = htmlSafe(
          i18n(key, {
            email: emailOrUsername,
            username: emailOrUsername,
          })
        );
      } else {
        key += data.user_found ? "_found" : "";

        this.emailOrUsername = "";
        this.offerHelp = i18n(key, {
          email: emailOrUsername,
          username: emailOrUsername,
        });

        this.helpSeen = !data.user_found;
      }
    } catch (error) {
      this.flash = extractError(error);
    } finally {
      this.disabled = false;
    }
  }
}
