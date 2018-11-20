import { loadTopicView } from "discourse/models/topic";

export default Ember.Route.extend({
  model(params) {
    let topicRecord = this.store.createRecord("topic", { id: params.id });
    let topic = loadTopicView(topicRecord).then(() => topicRecord);

    return Ember.RSVP.hash({
      topic,
      flaggedPosts: this.store.findAll("flagged-post", {
        filter: "active",
        topic_id: params.id
      })
    });
  },

  setupController(controller, hash) {
    controller.setProperties(hash);
  }
});
