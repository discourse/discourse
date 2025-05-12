import Service, { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";

const HISTORY_THRESHOLD = 1000;

// This service is responsible for managing the route history
// mainly used by the `BackButton` component
export default class RouteHistory extends Service {
  @service router;
  @service sessionStore;

  init() {
    super.init(...arguments);
    this.router.on("routeWillChange", this.routeWillChange);
  }

  willDestroy() {
    this.router.off("routeWillChange", this.routeWillChange);
  }

  get history() {
    const history = this.sessionStore.getObject("routeHistory");
    if (history === null) {
      return [];
    }
    return history;
  }

  addToHistory(url) {
    const history = this.history || [];
    history.unshift(url);
    if (history.length > HISTORY_THRESHOLD) {
      history.pop();
    }
    this.sessionStore.setObject({ key: "routeHistory", value: history });
  }

  @bind
  routeWillChange() {
    if (
      this.router.currentURL !== null &&
      this.router.currentURL !== this.lastURL // don't add the same URL twice
    ) {
      this.addToHistory(this.router.currentURL);
    }
  }

  get lastURL() {
    return this.history[0];
  }
}
