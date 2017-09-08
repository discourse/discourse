import FlaggedPost from 'admin/models/flagged-post';

export default Discourse.Route.extend({
  model() {
    return FlaggedPost.findAll({ filter: 'active' });
  }
});
