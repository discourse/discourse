import Route from "@ember/routing/route";

export default class AdminCustomizeEmailStyleRoute extends Route {
  model() {
    return this.store.find("email-style");
  }
}
