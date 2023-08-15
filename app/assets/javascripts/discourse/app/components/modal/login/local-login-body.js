import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { escapeExpression } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import { flashAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";
import getWebauthnCredential from "discourse/lib/webauthn";
import ForgotPassword from "discourse/components/modal/forgot-password";

export default class LocalLoginBody extends Component {
  @service modal;

  @tracked maskPassword = true;
  @tracked processingEmailLink = false;
  @tracked capsLockOn = false;

  get credentialsClass() {
    return this.args.showSecondFactor || this.args.showSecurityKey
      ? "hidden"
      : "";
  }

  get secondFactorClass() {
    return this.args.showSecondFactor || this.args.showSecurityKey
      ? ""
      : "hidden";
  }

  get disableLoginFields() {
    return this.args.showSecondFactor || this.args.showSecurityKey;
  }

  @action
  togglePasswordMask() {
    this.maskPassword = !this.maskPassword;
  }

  @action
  emailLogin(event) {
    event?.preventDefault();

    if (this.processingEmailLink) {
      return;
    }

    if (isEmpty(this.args.loginName)) {
      this.args.flashChanged(I18n.t("login.blank_username"));
      this.args.flashTypeChanged("info");
      return;
    }

    this.processingEmailLink = true;

    ajax("/u/email-login", {
      data: { login: this.args.loginName.trim() },
      type: "POST",
    })
      .then((data) => {
        const loginName = escapeExpression(this.args.loginName);
        const isEmail = loginName.match(/@/);
        let key = isEmail
          ? "email_login.complete_email"
          : "email_login.complete_username";
        if (data.user_found === false) {
          this.args.flashChanged = htmlSafe(
            I18n.t(`${key}_not_found`, {
              email: loginName,
              username: loginName,
            })
          );
          this.args.flashTypeChanged = "error";
        } else {
          let postfix = data.hide_taken ? "" : "_found";
          this.args.flashChanged(
            htmlSafe(
              I18n.t(`${key}${postfix}`, {
                email: loginName,
                username: loginName,
              })
            )
          );
          this.args.flashTypeChanged("success");
        }
      })
      .catch(flashAjaxError(this))
      .finally(() => (this.processingEmailLink = false));
  }

  @action
  handleForgotPassword(event) {
    event?.preventDefault();

    this.modal.show(ForgotPassword, {
      model: {
        emailOrUsername: this.args.loginName,
      },
    });
  }

  @action
  authenticateSecurityKey() {
    getWebauthnCredential(
      this.args.securityKeyChallenge,
      this.args.securityKeyAllowedCredentialIds,
      (credentialData) => {
        this.args.securityKeyCredentialChanged(credentialData);
        this.args.login();
      },
      (error) => {
        this.args.flashChanged(error);
        this.args.flashTypeChanged("error");
      }
    );
  }
}
