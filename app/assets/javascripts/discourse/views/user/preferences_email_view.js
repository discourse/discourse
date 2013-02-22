(function() {

  window.Discourse.PreferencesEmailView = Discourse.View.extend({
    templateName: 'user/email',
    classNames: ['user-preferences'],
    didInsertElement: function() {
      return jQuery('#change_email').focus();
    }
  });

}).call(this);
