(function() {

  window.Discourse.UserActivityView = Discourse.View.extend({
    templateName: 'user/activity',
    currentUserBinding: 'Discourse.currentUser',
    userBinding: 'controller.content',
    didInsertElement: function() {
      return window.scrollTo(0, 0);
    }
  });

}).call(this);
