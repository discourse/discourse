import Route from "@ember/routing/route";

export default class AdminApiKeysIndexRoute extends Route {
  model() {
    return this.store.findAll("api-key");
  }
}
