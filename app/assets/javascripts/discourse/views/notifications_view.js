(function() {

  window.Discourse.NotificationsView = Ember.View.extend({
    classNameBindings: ['content.read', ':notifications'],
    templateName: 'notifications'
  });

}).call(this);
