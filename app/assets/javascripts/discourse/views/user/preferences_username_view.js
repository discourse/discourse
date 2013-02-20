(function() {

  window.Discourse.PreferencesUsernameView = Ember.View.extend({
    templateName: 'user/username',
    classNames: ['user-preferences'],
    didInsertElement: function() {
      return jQuery('#change_username').focus();
    },
    keyDown: function(e) {
      if (e.keyCode === 13) {
        if (!this.get('controller').get('saveDisabled')) {
          return this.get('controller').changeUsername();
        } else {
          e.preventDefault();
          return false;
        }
      }
    }
  });

}).call(this);
