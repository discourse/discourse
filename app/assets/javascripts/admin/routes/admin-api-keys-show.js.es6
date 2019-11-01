export default Ember.Route.extend({
  model(params) {
    return this.store.find("api-key", params.api_key_id);
  }
});
