import { loadTopicView } from "discourse/models/post-stream";

export default Discourse.Route.extend({
  model(params) {
    const topic = this.store.createRecord("topic", { id: params.id });
    return loadTopicView(topic).then(() => topic);
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
