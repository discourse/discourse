import Topic from 'discourse/models/topic';
import DiscourseURL from 'discourse/lib/url';

export default Discourse.Route.extend({
  model: function(params) {
    return Topic.idForSlug(params.slug);
  },

  afterModel: function(result) {
    DiscourseURL.routeTo(result.url, { replaceURL: true });
  }
});
