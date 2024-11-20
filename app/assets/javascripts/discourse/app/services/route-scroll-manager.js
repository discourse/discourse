import { next, schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { isTesting } from "discourse-common/config/environment";
import { bind } from "discourse-common/utils/decorators";

const STORE_KEY = Symbol("scroll-location");

/**
 * This service is responsible for managing scroll position when transitioning.
 * When visiting a new route, this service will scroll to the top of the page.
 * When returning to a previously-visited route via the browser back button,
 * this service will scroll to the previous scroll position.
 *
 * To opt-out of the behaviour, individual routes can add a scrollOnTransition
 * boolean to their RouteInfo metadata using Ember's `buildRouteInfoMetadata` hook.
 */
@disableImplicitInjections
export default class RouteScrollManager extends Service {
  @service router;
  @service historyStore;

  scrollElement = isTesting()
    ? document.getElementById("ember-testing-container")
    : document.scrollingElement;

  init() {
    super.init(...arguments);
    this.router.on("routeDidChange", this.routeDidChange);
    this.router.on("routeWillChange", this.routeWillChange);
  }

  willDestroy() {
    this.router.off("routeDidChange", this.routeDidChange);
    this.router.off("routeWillChange", this.routeWillChange);
  }

  @bind
  routeWillChange() {
    this.historyStore.set(STORE_KEY, [
      this.scrollElement.scrollLeft,
      this.scrollElement.scrollTop,
    ]);
  }

  @bind
  routeDidChange(transition) {
    if (transition.isAborted) {
      return;
    }

    if (!this.#shouldScroll(transition.to)) {
      return;
    }

    const scrollLocation = this.historyStore.get(STORE_KEY) || [0, 0];

    next(() =>
      schedule("afterRender", () =>
        this.scrollElement.scrollTo(...scrollLocation)
      )
    );
  }

  #shouldScroll(routeInfo) {
    // Leafmost route has priority
    for (let route = routeInfo; route; route = route.parent) {
      const scrollOnTransition = route.metadata?.scrollOnTransition;
      if (typeof scrollOnTransition === "boolean") {
        return scrollOnTransition;
      }
    }

    // No overrides - default to true
    return true;
  }
}
