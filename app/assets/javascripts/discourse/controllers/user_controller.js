(function() {

  Discourse.UserController = Ember.ObjectController.extend({
    viewingSelf: (function() {
      return this.get('content.username') === Discourse.get('currentUser.username');
    }).property('content.username', 'Discourse.currentUser.username'),
    canSeePrivateMessages: (function() {
      return this.get('viewingSelf') || Discourse.get('currentUser.admin');
    }).property('viewingSelf', 'Discourse.currentUser')
  });

}).call(this);
