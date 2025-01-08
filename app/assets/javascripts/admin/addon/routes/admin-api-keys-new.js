import Route from "@ember/routing/route";

export default class AdminApiKeysNewRoute extends Route {
  model() {
    return this.store.createRecord("api-key");
  }
}
