import { service } from "@ember/service";
import cookie from "discourse/lib/cookie";
import getURL from "discourse/lib/get-url";
import { homepageNavigationDestination } from "discourse/lib/homepage-router-overrides";
import DiscourseURL from "discourse/lib/url";
import {
  isValidDestinationUrl,
  postRNWebviewMessage,
} from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";

export default class extends DiscourseRoute {
  @service capabilities;
  @service dialog;
  @service login;
  @service router;
  @service site;
  @service siteSettings;

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
    const { search: query } = window.location;
    const { referrer } = document;
    const { canSignUp } = this.controllerFor("application");
    const { isOnlyOneExternalLoginMethod, singleExternalLogin } = this.login;
    const redirect = auth_immediately || login_required || !from || wantsTo;
    const homepage = login_required
      ? "discovery.login-required"
      : homepageNavigationDestination();

    // Can't sign up when the site is read-only
    if (isReadOnly) {
      if (from) {
        transition.abort();
      } else {
        router.replaceWith(homepage).followRedirects();
      }

      dialog.alert(this.login.readOnlySignupMessage);
      return;
    }

    // In some cases, the user is only allowed to log in, not sign up
    if (!canSignUp && (invite_only || !auth_immediately)) {
      router.replaceWith(homepage).followRedirects();
      return;
    }

    // We're in the middle of an authentication flow
    if (document.getElementById("data-authentication")) {
      return;
    }

    // When inside a webview, it handles the login flow itself
    if (isAppWebview) {
      postRNWebviewMessage("showLogin", true);
    }

    // Automatically store the current URL (aka. the one **before** the transition)
    if (!currentUser) {
      if (isValidDestinationUrl(url)) {
        cookie("destination_url", url + query);
      } else if (DiscourseURL.isInternalTopic(referrer)) {
        cookie("destination_url", referrer);
      }
    }

    // Automatically kick off the external login if it's the only one available
    if (enable_discourse_connect) {
      if (redirect) {
        const returnPath = cookie("destination_url")
          ? getURL("/")
          : encodeURIComponent(url);
        window.location = getURL(`/session/sso?return_path=${returnPath}`);
        return new Promise(() => {}); // Prevents the transition from completing
      } else {
        router.replaceWith("discovery.login-required");
      }
    } else if (isOnlyOneExternalLoginMethod) {
      if (redirect) {
        singleExternalLogin({ signup: true });
        return new Promise(() => {}); // Prevents the transition from completing
      } else {
        router.replaceWith("discovery.login-required");
      }
    }
  }

  setupController(controller) {
    super.setupController(...arguments);

    if (cookie("email")) {
      controller.accountEmail = cookie("email");
    }

    controller.fetchConfirmationValue();
  }
}
