import Route from "@ember/routing/route";

export default class AdminWebHooksIndexRoute extends Route {
  model() {
    return this.store.findAll("web-hook");
  }
}
