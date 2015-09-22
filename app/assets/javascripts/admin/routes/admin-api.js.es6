export default Ember.Route.extend({
  model() {
    return Discourse.ApiKey.find();
  }
});
