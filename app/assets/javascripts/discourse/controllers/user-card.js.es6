export default Ember.Controller.extend({
  topic: Ember.inject.controller(),
  application: Ember.inject.controller(),

  actions: {
    togglePosts(user) {
      const topicController = this.get("topic");
      topicController.send("toggleParticipant", user);
    },

    showUser(user) {
      this.transitionToRoute("user", user);
    }
  }
});
