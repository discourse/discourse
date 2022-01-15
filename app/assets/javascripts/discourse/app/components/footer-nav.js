import { isAppWebview, postRNWebviewMessage } from "discourse/lib/utilities";
import MobileScrollDirection from "discourse/mixins/mobile-scroll-direction";
import MountWidget from "discourse/components/mount-widget";
import Scrolling from "discourse/mixins/scrolling";
import { observes } from "discourse-common/utils/decorators";
import { throttle } from "@ember/runloop";

const MOBILE_SCROLL_DIRECTION_CHECK_THROTTLE = 150;

const FooterNavComponent = MountWidget.extend(
  Scrolling,
  MobileScrollDirection,
  {
    widget: "footer-nav",
    mobileScrollDirection: null,
    scrollEventDisabled: false,
    classNames: ["footer-nav", "visible"],
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

      if (isAppWebview()) {
        this.appEvents.on("modal:body-shown", this, "_modalOn");
        this.appEvents.on("modal:body-dismissed", this, "_modalOff");
      }

      if (this.capabilities.isIpadOS) {
        document.body.classList.add("footer-nav-ipad");
      } else {
        this.bindScrolling();
        window.addEventListener("resize", this.scrolled, false);
        this.appEvents.on("composer:opened", this, "_composerOpened");
        this.appEvents.on("composer:closed", this, "_composerClosed");
        document.body.classList.add("footer-nav-visible");
      }
    },

    willDestroyElement() {
      this._super(...arguments);
      this.appEvents.off("page:changed", this, "_routeChanged");

      if (isAppWebview()) {
        this.appEvents.off("modal:body-shown", this, "_modalOn");
        this.appEvents.off("modal:body-removed", this, "_modalOff");
      }

      if (this.capabilities.isIpadOS) {
        document.body.classList.remove("footer-nav-ipad");
      } else {
        this.unbindScrolling();
        window.removeEventListener("resize", this.scrolled);
        this.appEvents.off("composer:opened", this, "_composerOpened");
        this.appEvents.off("composer:closed", this, "_composerClosed");
      }
    },

    // The user has scrolled the window, or it is finished rendering and ready for processing.
    scrolled() {
      if (
        this.isDestroyed ||
        this.isDestroying ||
        this._state !== "inDOM" ||
        this.scrollEventDisabled
      ) {
        return;
      }

      throttle(
        this,
        this.calculateDirection,
        window.pageYOffset,
        MOBILE_SCROLL_DIRECTION_CHECK_THROTTLE
      );
    },

    // We observe the scroll direction on mobile and if it's down, we show the topic
    // in the header, otherwise, we hide it.
    @observes("mobileScrollDirection")
    toggleMobileFooter() {
      this.element.classList.toggle(
        "visible",
        this.mobileScrollDirection === null ? true : false
      );
      document.body.classList.toggle(
        "footer-nav-visible",
        this.mobileScrollDirection === null ? true : false
      );
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
  }
);

export default FooterNavComponent;
