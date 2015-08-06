export default Ember.Route.extend({
  model() {
    return Discourse.SiteCustomization.findAll();
  }
});
