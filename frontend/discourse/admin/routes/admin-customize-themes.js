import { action } from "@ember/object";
import Route from "@ember/routing/route";

export default class AdminCustomizeThemesRoute extends Route {
  model() {
    return this.store.findAll("theme");
  }

  @action
  routeRefreshModel() {
    this.refresh();
  }
}
