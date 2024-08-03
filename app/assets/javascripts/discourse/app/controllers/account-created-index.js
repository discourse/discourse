import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { resendActivationEmail } from "discourse/lib/user-activation";
import { wavingHandURL } from "discourse/lib/waving-hand-url";
import getUrl from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class AccountCreatedIndexController extends Controller {
  @service router;

  envelopeImageUrl = getUrl("/images/envelope.svg");

  @discourseComputed
  welcomeTitle() {
    return I18n.t("invites.welcome_to", {
      site_name: this.siteSettings.title,
    });
  }

  @discourseComputed
  wavingHandURL() {
    return wavingHandURL();
  }

  @action
  sendActivationEmail() {
    resendActivationEmail(this.get("accountCreated.username")).then(() => {
      this.router.transitionTo("account-created.resent");
    });
  }

  @action
  editActivationEmail() {
    this.router.transitionTo("account-created.edit-email");
  }
}
