export default Discourse.Route.extend({
  model: function(params) {
    return Discourse.Topic.idForSlug(params.slug);
  },

  afterModel: function(result) {
    Discourse.URL.routeTo(result.url);
  }
});
