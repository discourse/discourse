export default Discourse.Route.extend({
  beforeModel: function(transition) {
    const self = this;
    if (Discourse.User.current()) {
      // User is logged in
      self.replaceWith("discovery.latest").then(function(e) {
        if (self.controllerFor("navigation/default").get("canCreateTopic")) {
          // User can create topic
          Ember.run.next(function() {
            e.send(
              "createNewTopicViaParams",
              transition.queryParams.title,
              transition.queryParams.body,
              transition.queryParams.category_id,
              transition.queryParams.category,
              transition.queryParams.tags
            );
          });
        }
      });
    } else {
      // User is not logged in
      $.cookie("destination_url", window.location.href);
      if (Discourse.showingSignup) {
        // We're showing the sign up modal
        Discourse.showingSignup = false;
      } else {
        self.replaceWith("login");
      }
    }
  }
});
