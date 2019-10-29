import MountWidget from "discourse/components/mount-widget";
import MobileScrollDirection from "discourse/mixins/mobile-scroll-direction";
import Scrolling from "discourse/mixins/scrolling";
import { observes } from "ember-addons/ember-computed-decorators";
import { isAppWebview, postRNWebviewMessage } from "discourse/lib/utilities";

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
        canGoForward: this.canGoForward
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
        $("body").addClass("footer-nav-ipad");
      } else {
        this.bindScrolling({ name: "footer-nav" });
        $(window).on("resize.footer-nav-on-scroll", () => this.scrolled());
        this.appEvents.on("composer:opened", this, "_composerOpened");
        this.appEvents.on("composer:closed", this, "_composerClosed");
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
        $("body").removeClass("footer-nav-ipad");
      } else {
        this.unbindScrolling("footer-nav");
        $(window).unbind("resize.footer-nav-on-scroll");
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

      const offset = window.pageYOffset || $("html").scrollTop();

      Ember.run.throttle(
        this,
        this.calculateDirection,
        offset,
        MOBILE_SCROLL_DIRECTION_CHECK_THROTTLE
      );
    },

    // We observe the scroll direction on mobile and if it's down, we show the topic
    // in the header, otherwise, we hide it.
    @observes("mobileScrollDirection")
    toggleMobileFooter() {
      $(this.element).toggleClass(
        "visible",
        this.mobileScrollDirection === null ? true : false
      );
      // body class used to adjust positioning of #topic-progress-wrapper
      $("body").toggleClass(
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
      postRNWebviewMessage(
        "headerBg",
        $(".modal-backdrop").css("background-color")
      );
    },

    _modalOff() {
      postRNWebviewMessage("headerBg", $(".d-header").css("background-color"));
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
    }
  }
);

export default FooterNavComponent;
