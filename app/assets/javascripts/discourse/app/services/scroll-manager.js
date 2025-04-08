import { scheduleOnce, throttle } from "@ember/runloop";
import Service, { service } from "@ember/service";

export default class ScrollManager extends Service {
  @service router;

  listeners = new Map();

  // Begin watching for scroll events. By default they will be called at max every 100ms.
  // call with {throttle: N} to change the throttle spacing
  bindScrolling(target, opts = {}) {
    console.log("bindScrolling from service");
    const throttleMs = opts.throttle || 100;

    // So we can not call the scrolled event while transitioning. There is no public API for this :'(
    // eslint-disable-next-line ember/no-private-routing-service
    const microLib = this.router._router._routerMicrolib;

    const scheduleScrolled = () => {
      console.log("scheduleScrolled from service");
      if (microLib.activeTransition) {
        return;
      }

      return scheduleOnce("afterRender", target, "scrolled");
    };

    const onScrollMethod = throttleMs
      ? () => throttle(target, scheduleScrolled, throttleMs, false)
      : scheduleScrolled;

    // Store the handler reference for unbinding later
    this.listeners.set(target, onScrollMethod);

    // Bind scroll events
    document.addEventListener("touchmove", onScrollMethod, { passive: true });
    window.addEventListener("scroll", onScrollMethod, { passive: true });
  }

  unbindScrolling(target) {
    const handler = this.listeners.get(target);
    if (handler) {
      document.removeEventListener("touchmove", handler);
      window.removeEventListener("scroll", handler);
      this.listeners.delete(target);
    }
  }
}
