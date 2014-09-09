export default Discourse.Route.extend({
  model: function() {
    var user = this.modelFor('user');
    return Discourse.NotificationContainer.loadHistory(undefined, user.get('username'));
  },

  setupController: function(controller, model) {
    this.controllerFor('user').set('indexStream', false);
    if (this.controllerFor('user_activity').get('content')) {
      this.controllerFor('user_activity').set('userActionType', -1);
    }
    controller.set('model', model);
    controller.set('user', this.modelFor('user'));
  },

  renderTemplate: function() {
    this.render('user-notification-history', {into: 'user', outlet: 'userOutlet'});
  }
});
