import Route from "@ember/routing/route";
import { service } from "discourse/lib/service";

export default class AdminCustomizeIndexRoute extends Route {
  @service router;

  beforeModel() {
    if (this.currentUser.admin) {
      this.router.transitionTo("adminCustomizeThemes");
    } else {
      this.router.transitionTo("adminWatchedWords");
    }
  }
}
