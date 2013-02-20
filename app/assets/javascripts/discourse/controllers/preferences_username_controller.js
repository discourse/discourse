(function() {

  Discourse.PreferencesUsernameController = Ember.ObjectController.extend(Discourse.Presence, {
    taken: false,
    saving: false,
    error: false,
    errorMessage: null,
    saveDisabled: (function() {
      if (this.get('saving')) {
        return true;
      }
      if (this.blank('newUsername')) {
        return true;
      }
      if (this.get('taken')) {
        return true;
      }
      if (this.get('unchanged')) {
        return true;
      }
      if (this.get('errorMessage')) {
        return true;
      }
      return false;
    }).property('newUsername', 'taken', 'errorMessage', 'unchanged', 'saving'),
    unchanged: (function() {
      return this.get('newUsername') === this.get('content.username');
    }).property('newUsername', 'content.username'),
    checkTaken: (function() {
      var _this = this;
      this.set('taken', false);
      this.set('errorMessage', null);
      if (this.blank('newUsername')) {
        return;
      }
      if (this.get('unchanged')) {
        return;
      }
      return Discourse.User.checkUsername(this.get('newUsername')).then(function(result) {
        if (result.errors) {
          return _this.set('errorMessage', result.errors.join(' '));
        } else if (result.available === false) {
          return _this.set('taken', true);
        }
      });
    }).observes('newUsername'),
    saveButtonText: (function() {
      if (this.get('saving')) {
        return Em.String.i18n("saving");
      }
      return Em.String.i18n("user.change_username.action");
    }).property('saving'),
    changeUsername: function() {
      var _this = this;
      return bootbox.confirm(Em.String.i18n("user.change_username.confirm"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), function(result) {
        if (result) {
          _this.set('saving', true);
          return _this.get('content').changeUsername(_this.get('newUsername')).then(function() {
            window.location = "/users/" + (_this.get('newUsername').toLowerCase()) + "/preferences";
          }, function() {
            /* Error
            */
            _this.set('error', true);
            return _this.set('saving', false);
          });
        }
      });
    }
  });

}).call(this);
