import Route from "@ember/routing/route";

export default class AdminCustomizeIndexRoute extends Route {
  beforeModel() {
    if (this.currentUser.admin) {
      this.transitionTo("adminCustomizeThemes");
    } else {
      this.transitionTo("adminWatchedWords");
    }
  }
}
