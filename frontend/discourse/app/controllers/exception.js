import { cached } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { alias, equal, gte, none } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
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

  @computed("thrown")
  get isNetwork() {
    // never made it on the wire
    if (this.thrown && this.thrown.readyState === 0) {
      return true;
    }

    // timed out
    if (this.thrown && this.thrown.jqTextStatus === "timeout") {
      return true;
    }

    return false;
  }

  @computed("isNetwork", "thrown.status", "thrown")
  get reason() {
    if (this.thrown.reason) {
      return this.thrown.reason;
    } else if (this.isNetwork) {
      return i18n("errors.reasons.network");
    } else if (this.thrown?.status >= 500) {
      return i18n("errors.reasons.server");
    } else if (this.thrown?.status === 404) {
      return i18n("errors.reasons.not_found");
    } else if (this.thrown?.status === 403) {
      return i18n("errors.reasons.forbidden");
    } else if (this.thrown === null) {
      return i18n("errors.reasons.unknown");
    } else {
      // TODO
      return i18n("errors.reasons.unknown");
    }
  }

  @computed(
    "networkFixed",
    "isNetwork",
    "thrown.status",
    "thrown.statusText",
    "thrown"
  )
  get desc() {
    if (this.thrown.desc) {
      return this.thrown.desc;
    } else if (this.networkFixed) {
      return i18n("errors.desc.network_fixed");
    } else if (this.isNetwork) {
      return i18n("errors.desc.network");
    } else if (this.thrown?.status === 404) {
      return i18n("errors.desc.not_found");
    } else if (this.thrown?.status === 403) {
      return i18n("errors.desc.forbidden");
    } else if (this.thrown?.status >= 500) {
      return i18n("errors.desc.server", {
        status: this.thrown?.status + " " + this.thrown?.statusText,
      });
    } else if (this.thrown === null) {
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

  @computed("networkFixed", "isNetwork", "lastTransition")
  get enabledButtons() {
    if (this.networkFixed) {
      return [this.buttons.ButtonLoadPage];
    } else if (this.isNetwork) {
      return [this.buttons.ButtonBackDim, this.buttons.ButtonTryAgain];
    } else if (!this.lastTransition) {
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
