import Route from "@ember/routing/route";

export default class AdminApiIndexRoute extends Route {
  beforeModel() {
    this.transitionTo("adminApiKeys");
  }
}
