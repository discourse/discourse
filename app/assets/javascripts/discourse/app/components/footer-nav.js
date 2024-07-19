import { service } from "@ember/service";
import MountWidget from "discourse/components/mount-widget";
import { postRNWebviewMessage } from "discourse/lib/utilities";
import { SCROLLED_UP, UNSCROLLED } from "discourse/services/scroll-direction";
import { bind, observes } from "discourse-common/utils/decorators";

const FooterNavComponent = MountWidget.extend({
  widget: "footer-nav",
  classNames: ["footer-nav", "visible"],
  scrollDirection: service(),
  routeHistory: [],
  currentRouteIndex: 0,
  canGoBack: false,
  canGoForward: false,
  backForwardClicked: null,

  buildArgs() {
    return {
      canGoBack: this.canGoBack,
      canGoForward: this.canGoForward,
    };
  },

  didInsertElement() {
    this._super(...arguments);
    this.appEvents.on("page:changed", this, "_routeChanged");

    if (this.capabilities.isAppWebview) {
      this.appEvents.on("modal:body-shown", this, "_modalOn");
      this.appEvents.on("modal:body-dismissed", this, "_modalOff");
    }

    if (this.capabilities.isIpadOS) {
      document.documentElement.classList.add("footer-nav-ipad");
    } else {
      this.appEvents.on("composer:opened", this, "_composerOpened");
      this.appEvents.on("composer:closed", this, "_composerClosed");
      document.documentElement.classList.add("footer-nav-visible");
    }

    this.scrollDirection.addObserver(
      "lastScrollDirection",
      this.toggleMobileFooter
    );
  },

  willDestroyElement() {
    this._super(...arguments);
    this.appEvents.off("page:changed", this, "_routeChanged");

    if (this.capabilities.isAppWebview) {
      this.appEvents.off("modal:body-shown", this, "_modalOn");
      this.appEvents.off("modal:body-removed", this, "_modalOff");
    }

    if (this.capabilities.isIpadOS) {
      document.documentElement.classList.remove("footer-nav-ipad");
    } else {
      this.unbindScrolling();
      window.removeEventListener("resize", this.scrolled);
      this.appEvents.off("composer:opened", this, "_composerOpened");
      this.appEvents.off("composer:closed", this, "_composerClosed");
    }

    this.scrollDirection.removeObserver(
      "lastScrollDirection",
      this.toggleMobileFooter
    );
  },

  @bind
  toggleMobileFooter() {
    const visible = [UNSCROLLED, SCROLLED_UP].includes(
      this.scrollDirection.lastScrollDirection
    );
    this.element.classList.toggle("visible", visible);
    document.documentElement.classList.toggle("footer-nav-visible", visible);
  },

  _routeChanged(route) {
    // only update route history if not using back/forward nav
    if (this.backForwardClicked) {
      this.backForwardClicked = null;
      return;
    }

    this.routeHistory.push(route.url);
    this.set("currentRouteIndex", this.routeHistory.length);

    this.queueRerender();
  },

  _composerOpened() {
    this.set("mobileScrollDirection", "down");
    this.set("scrollEventDisabled", true);
  },

  _composerClosed() {
    this.set("mobileScrollDirection", null);
    this.set("scrollEventDisabled", false);
  },

  _modalOn() {
    const backdrop = document.querySelector(".modal-backdrop");
    if (backdrop) {
      postRNWebviewMessage(
        "headerBg",
        getComputedStyle(backdrop)["background-color"]
      );
    }
  },

  _modalOff() {
    const dheader = document.querySelector(".d-header");
    if (dheader) {
      postRNWebviewMessage(
        "headerBg",
        getComputedStyle(dheader)["background-color"]
      );
    }
  },

  goBack() {
    this.set("currentRouteIndex", this.currentRouteIndex - 1);
    this.backForwardClicked = true;
    window.history.back();
  },

  goForward() {
    this.set("currentRouteIndex", this.currentRouteIndex + 1);
    this.backForwardClicked = true;
    window.history.forward();
  },

  @observes("currentRouteIndex")
  setBackForward() {
    let index = this.currentRouteIndex;

    this.set("canGoBack", index > 1 || document.referrer ? true : false);
    this.set("canGoForward", index < this.routeHistory.length ? true : false);
  },
});

export default FooterNavComponent;
