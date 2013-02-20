(function() {

  window.Discourse.PreferencesEmailView = Ember.View.extend({
    templateName: 'user/email',
    classNames: ['user-preferences'],
    didInsertElement: function() {
      return jQuery('#change_email').focus();
    }
  });

}).call(this);
