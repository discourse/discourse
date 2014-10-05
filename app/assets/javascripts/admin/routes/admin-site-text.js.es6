export default Ember.Route.extend({
  model: function() {
    return Discourse.SiteTextType.findAll();
  }
});
