import MountWidget from "discourse/components/mount-widget";
import MobileScrollDirection from "discourse/mixins/mobile-scroll-direction";
import Scrolling from "discourse/mixins/scrolling";
import { observes } from "ember-addons/ember-computed-decorators";

const MOBILE_SCROLL_DIRECTION_CHECK_THROTTLE = 150;

const MobileFooterComponent = MountWidget.extend(
  Scrolling,
  MobileScrollDirection,
  {
    widget: "mobile-footer-nav",
    mobileScrollDirection: null,
    scrollEventDisabled: false,
    classNames: ["mobile-footer", "visible"],
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
      this.bindScrolling({ name: "mobile-footer" });
      $(window).on("resize.mobile-footer-on-scroll", () => this.scrolled());
      this.appEvents.on("page:changed", this, "_routeChanged");
      this.appEvents.on("composer:opened", this, "_composerOpened");
      this.appEvents.on("composer:closed", this, "_composerClosed");
    },

    willDestroyElement() {
      this._super(...arguments);
      this.unbindScrolling("mobile-footer");
      $(window).unbind("resize.mobile-footer-on-scroll");
      this.appEvents.off("page:changed", this, "_routeChanged");
      this.appEvents.off("composer:opened", this, "_composerOpened");
      this.appEvents.off("composer:closed", this, "_composerClosed");
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
      this.$().toggleClass(
        "visible",
        this.mobileScrollDirection === null ? true : false
      );
      // body class used to adjust positioning of #topic-progress-wrapper
      $("body").toggleClass(
        "mobile-footer-nav-visible",
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

    goBack() {
      this.set("currentRouteIndex", this.get("currentRouteIndex") - 1);
      this.backForwardClicked = true;
      window.history.back();
    },

    goForward() {
      this.set("currentRouteIndex", this.get("currentRouteIndex") + 1);
      this.backForwardClicked = true;
      window.history.forward();
    },

    @observes("currentRouteIndex")
    setBackForward() {
      let index = this.get("currentRouteIndex");

      this.set("canGoBack", index > 1 ? true : false);
      this.set("canGoForward", index < this.routeHistory.length ? true : false);
    }
  }
);

export default MobileFooterComponent;
