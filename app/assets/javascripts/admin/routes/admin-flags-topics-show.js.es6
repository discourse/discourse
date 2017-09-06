import { loadTopicView } from 'discourse/models/topic';
import FlaggedPost from 'admin/models/flagged-post';

export default Ember.Route.extend({
  model(params) {
    let topicRecord = this.store.createRecord('topic', { id: params.id });
    let topic = loadTopicView(topicRecord).then(() => topicRecord);

    return Ember.RSVP.hash({
      topic,
      flaggedPosts: FlaggedPost.findAll({ filter: 'active' })
    });
  },

  setupController(controller, hash) {
    controller.setProperties(hash);
  }
});
