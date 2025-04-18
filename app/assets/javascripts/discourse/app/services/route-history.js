import Service, { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { defaultHomepage } from "discourse/lib/utilities";

// This service is responsible for managing the route history
// mainly used by the `BackButton` component
export default class RouteHistory extends Service {
  @service router;

  init() {
    super.init(...arguments);
    this.router.on("routeWillChange", this.routeWillChange);
  }

  willDestroy() {
    this.router.off("routeWillChange", this.routeWillChange);
  }

  @bind
  routeWillChange() {
    if (this.router.currentURL !== null) {
      sessionStorage.setItem("lastUrl", this.router.currentURL);
    }
  }

  get lastKnownURL() {
    const url = sessionStorage.getItem("lastUrl");

    if (url !== null && url !== "/") {
      return url;
    }

    return this.router.urlFor(`discovery.${defaultHomepage()}`);
  }
}
