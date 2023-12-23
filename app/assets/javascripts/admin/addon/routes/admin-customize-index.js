import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";
import allowClassModifications from "discourse/lib/allow-class-modifications";

@allowClassModifications
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
