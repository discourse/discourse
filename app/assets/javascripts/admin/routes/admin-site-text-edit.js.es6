export default Ember.Route.extend({
  model: function(params) {
    return Discourse.SiteText.find(params.text_type);
  }
});
