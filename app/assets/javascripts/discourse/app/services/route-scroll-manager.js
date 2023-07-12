import Service, { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import { schedule } from "@ember/runloop";
import { isTesting } from "discourse-common/config/environment";

const MAX_SCROLL_LOCATIONS = 100;

export default class RouteScrollManager extends Service {
  @service router;

  scrollLocationHistory = new Map();
  uuid;

  scrollElement = isTesting()
    ? document.getElementById("ember-testing-container")
    : document.scrollingElement;

  @bind
  routeWillChange() {
    if (!this.uuid) {
      return;
    }
    this.scrollLocationHistory.set(this.uuid, [
      this.scrollElement.scrollLeft,
      this.scrollElement.scrollTop,
    ]);
    this.#pruneOldScrollLocations();
  }

  @bind
  routeDidChange(transition) {
    const newUuid = this.router.location.getState?.().uuid;

    if (newUuid === this.uuid) {
      // routeDidChange fired without the history state actually changing. Most likely a refresh.
      // Forget the previously-stored scroll location so that we scroll to the top
      this.scrollLocationHistory.delete(this.uuid);
    }

    this.uuid = newUuid;

    if (!this.#shouldScroll(transition.to)) {
      return;
    }

    const scrollLocation = this.scrollLocationHistory.get(this.uuid) || [0, 0];
    schedule("afterRender", () => {
      this.scrollElement.scrollTo(...scrollLocation);
    });
  }

  #pruneOldScrollLocations() {
    while (this.scrollLocationHistory.size > MAX_SCROLL_LOCATIONS) {
      // JS Set guarantees keys will be returned in insertion order
      const oldestUUID = this.scrollLocationHistory.keys().next().value;
      this.scrollLocationHistory.delete(oldestUUID);
    }
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

  init() {
    super.init(...arguments);
    this.router.on("routeDidChange", this.routeDidChange);
    this.router.on("routeWillChange", this.routeWillChange);
  }

  willDestroy() {
    this.router.off("routeDidChange", this.routeDidChange);
    this.router.off("routeWillChange", this.routeWillChange);
  }
}
