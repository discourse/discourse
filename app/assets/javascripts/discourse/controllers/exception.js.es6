import { equal, gte, none, alias } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import Controller from "@ember/controller";
import discourseComputed, { on } from "discourse-common/utils/decorators";

const ButtonBackBright = {
    classes: "btn-primary",
    action: "back",
    key: "errors.buttons.back"
  },
  ButtonBackDim = {
    classes: "",
    action: "back",
    key: "errors.buttons.back"
  },
  ButtonTryAgain = {
    classes: "btn-primary",
    action: "tryLoading",
    key: "errors.buttons.again",
    icon: "sync"
  },
  ButtonLoadPage = {
    classes: "btn-primary",
    action: "tryLoading",
    key: "errors.buttons.fixed"
  };

// The controller for the nice error page
export default Controller.extend({
  thrown: null,
  lastTransition: null,

  @discourseComputed
  isNetwork() {
    // never made it on the wire
    if (this.get("thrown.readyState") === 0) return true;

    // timed out
    if (this.get("thrown.jqTextStatus") === "timeout") return true;

    return false;
  },

  isNotFound: equal("thrown.status", 404),
  isForbidden: equal("thrown.status", 403),
  isServer: gte("thrown.status", 500),
  isUnknown: none("isNetwork", "isServer"),

  // TODO
  // make ajax requests to /srv/status with exponential backoff
  // if one succeeds, set networkFixed to true, which puts a "Fixed!" message on the page
  networkFixed: false,
  loading: false,

  @on("init")
  _init() {
    this.set("loading", false);
  },

  @discourseComputed("isNetwork", "isServer", "isUnknown")
  reason() {
    if (this.isNetwork) {
      return I18n.t("errors.reasons.network");
    } else if (this.isServer) {
      return I18n.t("errors.reasons.server");
    } else if (this.isNotFound) {
      return I18n.t("errors.reasons.not_found");
    } else if (this.isForbidden) {
      return I18n.t("errors.reasons.forbidden");
    } else {
      // TODO
      return I18n.t("errors.reasons.unknown");
    }
  },

  requestUrl: alias("thrown.requestedUrl"),

  @discourseComputed("networkFixed", "isNetwork", "isServer", "isUnknown")
  desc() {
    if (this.networkFixed) {
      return I18n.t("errors.desc.network_fixed");
    } else if (this.isNetwork) {
      return I18n.t("errors.desc.network");
    } else if (this.isNotFound) {
      return I18n.t("errors.desc.not_found");
    } else if (this.isServer) {
      return I18n.t("errors.desc.server", {
        status: this.get("thrown.status") + " " + this.get("thrown.statusText")
      });
    } else {
      // TODO
      return I18n.t("errors.desc.unknown");
    }
  },

  @discourseComputed("networkFixed", "isNetwork", "isServer", "isUnknown")
  enabledButtons() {
    if (this.networkFixed) {
      return [ButtonLoadPage];
    } else if (this.isNetwork) {
      return [ButtonBackDim, ButtonTryAgain];
    } else {
      return [ButtonBackBright, ButtonTryAgain];
    }
  },

  actions: {
    back() {
      window.history.back();
    },

    tryLoading() {
      this.set("loading", true);

      schedule("afterRender", () => {
        this.lastTransition.retry();
        this.set("loading", false);
      });
    }
  }
});
