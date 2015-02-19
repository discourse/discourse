import ShowFooter from "discourse/mixins/show-footer";

export default Discourse.Route.extend(ShowFooter, {
  actions: {
    didTransition: function() {
      this.controllerFor("user_notifications")._showFooter();
      return true;
    }
  },

  model: function() {
    var user = this.modelFor('user');
    return Discourse.NotificationContainer.loadHistory(undefined, user.get('username'));
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    controller.set('user', this.modelFor('user'));

    if (this.controllerFor('user_activity').get('content')) {
      this.controllerFor('user_activity').set('userActionType', -1);
    }

    // properly initialize "canLoadMore"
    controller.set("canLoadMore", model.get("length") === 60);
  },

  renderTemplate: function() {
    this.render('user-notification-history', {into: 'user'});
  }
});
