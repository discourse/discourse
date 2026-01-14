import { cached } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { alias, equal, gte, none } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import discourseComputed from "discourse/lib/decorators";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

/**
 * You can throw an instance of this error during a route's beforeModel/model/afterModel hooks.
 * It will be caught by the top-level ApplicationController, and cause this Exception controller/template
 * to be rendered without changing the URL.
 */
export class RouteException {
  status;
  reason;

  constructor({ status, reason, desc }) {
    this.status = status;
    this.reason = reason;
    this.desc = desc;
  }
}

// The controller for the nice error page
export default class ExceptionController extends Controller {
  thrown;
  lastTransition;

  @equal("thrown.status", 404) isNotFound;
  @equal("thrown.status", 403) isForbidden;
  @gte("thrown.status", 500) isServer;
  @none("isNetwork", "isServer") isUnknown;

  // Handling for the detailed_404 setting (which actually creates 403s)
  @alias("thrown.responseJSON.extras.html") errorHtml;

  // TODO
  // make ajax requests to /srv/status with exponential backoff
  // if one succeeds, set networkFixed to true, which puts a "Fixed!" message on the page
  networkFixed = false;

  loading = false;

  @alias("thrown.requestedUrl") requestUrl;

  @discourseComputed("thrown")
  isNetwork(thrown) {
    // never made it on the wire
    if (thrown && thrown.readyState === 0) {
      return true;
    }

    // timed out
    if (thrown && thrown.jqTextStatus === "timeout") {
      return true;
    }

    return false;
  }

  @discourseComputed("isNetwork", "thrown.status", "thrown")
  reason(isNetwork, thrownStatus, thrown) {
    if (thrown.reason) {
      return thrown.reason;
    } else if (isNetwork) {
      return i18n("errors.reasons.network");
    } else if (thrownStatus >= 500) {
      return i18n("errors.reasons.server");
    } else if (thrownStatus === 404) {
      return i18n("errors.reasons.not_found");
    } else if (thrownStatus === 403) {
      return i18n("errors.reasons.forbidden");
    } else if (thrown === null) {
      return i18n("errors.reasons.unknown");
    } else {
      // TODO
      return i18n("errors.reasons.unknown");
    }
  }

  @discourseComputed(
    "networkFixed",
    "isNetwork",
    "thrown.status",
    "thrown.statusText",
    "thrown"
  )
  desc(networkFixed, isNetwork, thrownStatus, thrownStatusText, thrown) {
    if (thrown.desc) {
      return thrown.desc;
    } else if (networkFixed) {
      return i18n("errors.desc.network_fixed");
    } else if (isNetwork) {
      return i18n("errors.desc.network");
    } else if (thrownStatus === 404) {
      return i18n("errors.desc.not_found");
    } else if (thrownStatus === 403) {
      return i18n("errors.desc.forbidden");
    } else if (thrownStatus >= 500) {
      return i18n("errors.desc.server", {
        status: thrownStatus + " " + thrownStatusText,
      });
    } else if (thrown === null) {
      return i18n("errors.desc.unknown");
    } else {
      // TODO
      return i18n("errors.desc.unknown");
    }
  }

  @cached
  get buttons() {
    return {
      ButtonBackBright: {
        classes: "btn-primary",
        action: this.back,
        key: "errors.buttons.back",
      },
      ButtonBackDim: {
        classes: "",
        action: this.back,
        key: "errors.buttons.back",
      },
      ButtonTryAgain: {
        classes: "btn-primary",
        action: this.tryLoading,
        key: "errors.buttons.again",
        icon: "arrows-rotate",
      },
      ButtonLoadPage: {
        classes: "btn-primary",
        action: this.tryLoading,
        key: "errors.buttons.fixed",
      },
    };
  }

  @discourseComputed("networkFixed", "isNetwork", "lastTransition")
  enabledButtons(networkFixed, isNetwork, lastTransition) {
    if (networkFixed) {
      return [this.buttons.ButtonLoadPage];
    } else if (isNetwork) {
      return [this.buttons.ButtonBackDim, this.buttons.ButtonTryAgain];
    } else if (!lastTransition) {
      return [this.buttons.ButtonBackBright];
    } else {
      return [this.buttons.ButtonBackBright, this.buttons.ButtonTryAgain];
    }
  }

  @action
  back() {
    // Strip off subfolder
    const currentURL = DiscourseURL.router.location.getURL();
    if (this.lastTransition?.method === "replace") {
      this.setProperties({ lastTransition: null, thrown: null });
      // Can't use routeTo because it handles navigation to the same page
      DiscourseURL.handleURL(currentURL);
    } else {
      window.history.back();
    }
  }

  @action
  tryLoading() {
    this.set("loading", true);

    schedule("afterRender", () => {
      const transition = this.lastTransition;
      this.setProperties({ lastTransition: null, thrown: null });
      transition.retry();
      this.set("loading", false);
    });
  }
}
