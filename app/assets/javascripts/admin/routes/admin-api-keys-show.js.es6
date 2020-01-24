import Route from "@ember/routing/route";

export default Route.extend({
  model(params) {
    return this.store.find("api-key", params.api_key_id);
  }
});
