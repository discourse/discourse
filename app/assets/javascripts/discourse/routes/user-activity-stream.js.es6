import ShowFooter from "discourse/mixins/show-footer";

export default Discourse.Route.extend(ShowFooter, {
  model: function() {
    return this.modelFor('user').get('stream');
  },

  afterModel: function() {
    return this.modelFor('user').get('stream').filterBy(this.get('userActionType'));
  },

  renderTemplate: function() {
    this.render('user_stream');
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    this.controllerFor('user-activity').set('userActionType', this.get('userActionType'));
  },

  actions: {

    didTransition: function() {
      this.controllerFor("user-activity")._showFooter();
      return true;
    },

    removeBookmark: function(userAction) {
      var self = this;
      Discourse.Post.bookmark(userAction.get('post_id'), false)
               .then(function() {
                  // remove the user action from the stream
                  self.modelFor("user").get("stream").remove(userAction);
                  // update the counts
                  self.modelFor("user").get("stats").forEach(function (stat) {
                    if (stat.get("action_type") === userAction.action_type) {
                      stat.decrementProperty("count");
                    }
                  });
                });
    },

  }
});
