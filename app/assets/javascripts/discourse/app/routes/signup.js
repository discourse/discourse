import { service } from "@ember/service";
import cookie from "discourse/lib/cookie";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import {
  defaultHomepage,
  isValidDestinationUrl,
  postRNWebviewMessage,
} from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class extends DiscourseRoute {
  @service capabilities;
  @service dialog;
  @service login;
  @service router;
  @service site;
  @service siteSettings;

  #isRedirecting = false;

  beforeModel(transition) {
    const { from, wantsTo } = transition;
    const { currentUser, dialog, router } = this;
    const { isReadOnly } = this.site;
    const { isAppWebview } = this.capabilities;
    const {
      auth_immediately,
      enable_discourse_connect,
      invite_only,
      login_required,
    } = this.siteSettings;
    const { pathname: url } = window.location;
    const { referrer } = document;
    const { canSignUp } = this.controllerFor("application");
    const { isOnlyOneExternalLoginMethod, singleExternalLogin } = this.login;

    // Can't sign up when the site is read-only
    if (isReadOnly) {
      transition.abort();
      dialog.alert(i18n("read_only_mode.login_disabled"));
      return;
    }

    // In some cases, the user is only allowed to log in, not sign up
    if (!canSignUp && (invite_only || !auth_immediately)) {
      const route = `discovery.${login_required ? "login-required" : defaultHomepage()}`;
      router.replaceWith(route).followRedirects();
      return;
    }

    // We're in the middle of an authentication flow
    if (document.getElementById("data-authentication")) {
      return;
    }

    // When inside a webview, it handles the login flow itself
    if (isAppWebview) {
      postRNWebviewMessage("showLogin", true);
      return;
    }

    // When Discourse Connect is enabled, redirect to the SSO endpoint
    if (auth_immediately && enable_discourse_connect) {
      const returnPath = cookie("destination_url")
        ? getURL("/")
        : encodeURIComponent(url);
      window.location = getURL(`/session/sso?return_path=${returnPath}`);
      return;
    }

    // Automatically store the current URL (aka. the one **before** the transition)
    if (!currentUser) {
      if (isValidDestinationUrl(url)) {
        cookie("destination_url", url);
      } else if (DiscourseURL.isInternalTopic(referrer)) {
        cookie("destination_url", referrer);
      }
    }

    // Automatically kick off the external login if it's the only one available
    if (isOnlyOneExternalLoginMethod) {
      if (auth_immediately || login_required || !from || wantsTo) {
        this.#isRedirecting = true;
        singleExternalLogin({ signup: true });
      } else {
        router.replaceWith("discovery.login-required");
      }
    }
  }

  setupController(controller) {
    const { enable_discourse_connect } = this.siteSettings;

    super.setupController(...arguments);

    // We're in the middle of an authentication flow
    if (document.getElementById("data-authentication")) {
      return;
    }

    // Shows the loading spinner while waiting for the redirection to external auth
    controller.isRedirectingToExternalAuth =
      this.#isRedirecting || enable_discourse_connect;
  }
}
