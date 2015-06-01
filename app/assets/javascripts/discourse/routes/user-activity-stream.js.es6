import ShowFooter from "discourse/mixins/show-footer";
import ViewingActionType from "discourse/mixins/viewing-action-type";

export default Discourse.Route.extend(ShowFooter, ViewingActionType, {
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
    this.viewingActionType(this.get('userActionType'));
  },

  actions: {

    didTransition: function() {
      this.controllerFor("user-activity")._showFooter();
      return true;
    },

    removeBookmark: function(userAction) {
      var user = this.modelFor('user');
      Discourse.Post.updateBookmark(userAction.get('post_id'), false)
        .then(function() {
          // remove the user action from the stream
          user.get('stream').remove(userAction);
          // update the counts
          user.get('stats').forEach(function (stat) {
            if (stat.get("action_type") === userAction.action_type) {
              stat.decrementProperty("count");
            }
          });
        });
    },

  }
});
