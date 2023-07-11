import Service, { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import { schedule } from "@ember/runloop";
const MAX_SCROLL_LOCATIONS = 100;

export default class RouteScrollManager extends Service {
  @service router;

  scrollLocationHistory = new Map();
  uuid;

  @bind
  routeWillChange() {
    if (!this.uuid) {
      return;
    }
    this.scrollLocationHistory.set(this.uuid, [window.scrollX, window.scrollY]);
    this.#pruneOldScrollLocations();
  }

  @bind
  routeDidChange() {
    this.uuid = this.router.location.getState?.().uuid;

    const scrollLocation = this.scrollLocationHistory.get(this.uuid) || [0, 0];
    schedule("afterRender", () => {
      window.scrollTo(...scrollLocation);
    });
  }

  #pruneOldScrollLocations() {
    while (this.scrollLocationHistory.size > MAX_SCROLL_LOCATIONS) {
      const oldestUUID = this.scrollLocationHistory.keys().next().value;
      this.scrollLocationHistory.delete(oldestUUID);
    }
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
