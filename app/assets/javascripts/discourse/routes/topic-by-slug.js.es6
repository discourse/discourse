import Topic from 'discourse/models/topic';

export default Discourse.Route.extend({
  model: function(params) {
    return Topic.idForSlug(params.slug);
  },

  afterModel: function(result) {
    Discourse.URL.routeTo(result.url, { replaceURL: true });
  }
});
