export default Discourse.Route.extend({
  beforeModel: function(transition) {
    const self = this;
    if (Discourse.User.current()) {
      // User is logged in
      self.replaceWith('discovery.latest').then(function(e) {
        if (self.controllerFor('navigation/default').get('canCreateTopic')) {
          // User can create topic
          Ember.run.next(function() {
            e.send('createNewTopicViaParams', transition.queryParams.title, transition.queryParams.body, transition.queryParams.category_id, transition.queryParams.category);
          });
        }
      });
    } else {
      // User is not logged in
      self.session.set("shouldRedirectToUrl", window.location.href);
      self.replaceWith('login');
    }
  }
});
