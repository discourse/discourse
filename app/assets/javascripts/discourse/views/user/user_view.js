(function() {

  window.Discourse.UserView = Ember.View.extend({
    templateName: 'user/user',
    userBinding: 'controller.content',
    updateTitle: (function() {
      var username;
      username = this.get('user.username');
      if (username) {
        return Discourse.set('title', "" + (Em.String.i18n("user.profile")) + " - " + username);
      }
    }).observes('user.loaded', 'user.username')
  });

}).call(this);
