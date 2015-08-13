import PostStream from "discourse/models/post-stream";

export default Discourse.Route.extend({
  model(params) {
    const topic = this.store.createRecord("topic", { id: params.id });
    return PostStream.loadTopicView(params.id).then(json => {
      topic.updateFromJson(json);
      return topic;
    });
  },

  afterModel(topic) {
    // hide the notification reason text
    topic.set("details.notificationReasonText", null);
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
