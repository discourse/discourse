(function() {

  window.Discourse.UserInvitedRoute = Discourse.Route.extend({
    renderTemplate: function() {
      return this.render({
        into: 'user',
        outlet: 'userOutlet'
      });
    },
    setupController: function(controller) {
      var _this = this;
      return Discourse.InviteList.findInvitedBy(this.controllerFor('user').get('content')).then(function(invited) {
        return controller.set('content', invited);
      });
    }
  });

}).call(this);
