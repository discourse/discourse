(function() {

  window.Discourse.UserActivityRoute = Discourse.Route.extend({
    renderTemplate: function() {
      return this.render({
        into: 'user',
        outlet: 'userOutlet'
      });
    },
    setupController: function(controller) {
      var userController;
      userController = this.controllerFor('user');
      userController.set('filter', null);
      return controller.set('content', userController.get('content'));
    }
  });

}).call(this);
