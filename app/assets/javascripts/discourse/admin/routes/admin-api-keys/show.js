import Route from "@ember/routing/route";

export default class AdminApiKeysShowRoute extends Route {
  model(params) {
    return this.store.find("api-key", params.api_key_id);
  }
}
