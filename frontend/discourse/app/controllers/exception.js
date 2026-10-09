import { cached, tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

/**
 * You can throw an instance of this error during a route's beforeModel/model/afterModel hooks.
 * It will be caught by the application route's error handler, and cause this Exception
 * controller/template to be rendered without changing the URL.
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
  @service exception;

  // Handling for the detailed_404 setting (which actually creates 403s)

  // TODO
  // make ajax requests to /srv/status with exponential backoff
  // if one succeeds, set networkFixed to true, which puts a "Fixed!" message on the page
  @tracked networkFixed = false;

  @tracked loading = false;

  get thrown() {
    return this.exception.thrown;
  }

  get lastTransition() {
    return this.exception.lastTransition;
  }

  get isNotFound() {
    return this.thrown?.status === 404;
  }

  get isForbidden() {
    return this.thrown?.status === 403;
  }

  get isServer() {
    return this.thrown?.status >= 500;
  }

  get isUnknown() {
    return this.isNetwork == null;
  }

  get errorHtml() {
    return this.thrown?.responseJSON?.extras?.html;
  }

  get requestUrl() {
    return this.thrown?.requestedUrl;
  }

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

  get reason() {
    if (this.thrown?.reason) {
      return this.thrown.reason;
    } else if (this.isNetwork) {
      return i18n("errors.reasons.network");
    } else if (this.thrown?.status >= 500) {
      return i18n("errors.reasons.server");
    } else if (this.thrown?.status === 404) {
      return i18n("errors.reasons.not_found");
    } else if (this.thrown?.status === 403) {
      return i18n("errors.reasons.forbidden");
    } else {
      return i18n("errors.reasons.unknown");
    }
  }

  get desc() {
    if (this.thrown?.desc) {
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
    } else {
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
      this.exception.clear();
      // Can't use routeTo because it handles navigation to the same page
      DiscourseURL.handleURL(currentURL);
    } else {
      window.history.back();
    }
  }

  @action
  tryLoading() {
    this.loading = true;

    schedule("afterRender", () => {
      const transition = this.lastTransition;
      this.exception.clear();
      transition.retry();
      this.loading = false;
    });
  }
}
