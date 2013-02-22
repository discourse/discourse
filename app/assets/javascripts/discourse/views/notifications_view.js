(function() {

  window.Discourse.NotificationsView = Discourse.View.extend({
    classNameBindings: ['content.read', ':notifications'],
    templateName: 'notifications'
  });

}).call(this);
