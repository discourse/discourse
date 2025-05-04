import { scheduleOnce, throttle } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

/**
 * Service for managing scroll event handling across the application
 *
 * This service provides methods for binding and unbinding scroll events
 * on window/document, with throttling to prevent performance issues.
 * Components can use this service to respond to user scrolling.
 *
 * @class ScrollManager
 */
@disableImplicitInjections
export default class ScrollManager extends Service {
  @service router;

  listeners = new Map();

  /**
   * Binds scroll events to a component and calls its 'scrolled' method when scrolling occurs
   *
   * @method bindScrolling
   * @param {Object} target The component that will receive 'scrolled' method calls
   * @param {Object} [opts={}] Configuration options
   * @param {Number} [opts.throttle=100] Throttle time in milliseconds; this is the time interval between every call of the scroll event
   * @public
   *
   * @example
   * ```javascript
   * // In a component:
   * @service scrollManager;
   *
   * didInsertElement() {
   *   super.didInsertElement(...arguments);
   *   this.scrollManager.bindScrolling(this);
   * }
   *
   * willDestroyElement() {
   *   super.willDestroyElement(...arguments);
   *   this.scrollManager.unbindScrolling(this);
   * }
   *
   * scrolled() {
   *   // Handle scroll event
   * }
   * ```
   */
  bindScrolling(target, opts = {}) {
    const throttleMs = opts.throttle || 100;

    // So we can not call the scrolled event while transitioning. There is no public API for this :'(
    // eslint-disable-next-line ember/no-private-routing-service
    const microLib = this.router._router._routerMicrolib;

    const scheduleScrolled = () => {
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

  /**
   * Unbinds scroll events from a component
   *
   * @method unbindScrolling
   * @param {Object} target The component to unbind scroll events from
   * @public
   */
  unbindScrolling(target) {
    const handler = this.listeners.get(target);
    if (handler) {
      document.removeEventListener("touchmove", handler);
      window.removeEventListener("scroll", handler);
      this.listeners.delete(target);
    }
  }
}
