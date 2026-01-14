import Route from "@ember/routing/route";
import { service } from "@ember/service";

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
