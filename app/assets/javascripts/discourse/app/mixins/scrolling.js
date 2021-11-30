import Mixin from "@ember/object/mixin";
import { scheduleOnce, throttle } from "@ember/runloop";
import { inject as service } from "@ember/service";

/**
  This object provides the DOM methods we need for our Mixin to bind to scrolling
  methods in the browser. By removing them from the Mixin we can test them
  easier.
**/
const ScrollingDOMMethods = {
  bindOnScroll(onScrollMethod) {
    document.addEventListener("touchmove", onScrollMethod, { passive: true });
    window.addEventListener("scroll", onScrollMethod, { passive: true });
  },

  unbindOnScroll(onScrollMethod) {
    document.removeEventListener("touchmove", onScrollMethod);
    window.removeEventListener("scroll", onScrollMethod);
  },

  screenNotFull() {
    return window.height > document.querySelector("#main").offsetHeight;
  },
};

const Scrolling = Mixin.create({
  router: service(),

  // Begin watching for scroll events. By default they will be called at max every 100ms.
  // call with {throttle: N} to change the throttle spacing
  bindScrolling(opts = {}) {
    if (!opts.throttle) {
      opts.throttle = 100;
    }
    // So we can not call the scrolled event while transitioning. There is no public API for this :'(
    const microLib = this.router._router._routerMicrolib;

    let scheduleScrolled = () => {
      if (microLib.activeTransition) {
        return;
      }

      return scheduleOnce("afterRender", this, "scrolled");
    };

    let onScrollMethod;
    if (opts.throttle) {
      onScrollMethod = () =>
        throttle(this, scheduleScrolled, opts.throttle, false);
    } else {
      onScrollMethod = scheduleScrolled;
    }

    this._scrollingMixinOnScrollMethod = onScrollMethod;
    ScrollingDOMMethods.bindOnScroll(onScrollMethod);
  },

  screenNotFull: () => ScrollingDOMMethods.screenNotFull(),

  unbindScrolling() {
    ScrollingDOMMethods.unbindOnScroll(this._scrollingMixinOnScrollMethod);
  },
});

export { ScrollingDOMMethods };
export default Scrolling;
