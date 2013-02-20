(function() {

  window.Discourse.RestrictedUserRoute = Discourse.Route.extend({
    enter: function(router, context) {
      var user;
      user = this.controllerFor('user').get('content');
      this.allowed = user.can_edit;
    },
    redirect: function() {
      if (!this.allowed) {
        return this.transitionTo('user.activity');
      }
    }
  });

}).call(this);
