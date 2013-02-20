(function() {

  Discourse.PreferencesEmailController = Ember.ObjectController.extend(Discourse.Presence, {
    taken: false,
    saving: false,
    error: false,
    success: false,
    saveDisabled: (function() {
      if (this.get('saving')) {
        return true;
      }
      if (this.blank('newEmail')) {
        return true;
      }
      if (this.get('taken')) {
        return true;
      }
      if (this.get('unchanged')) {
        return true;
      }
    }).property('newEmail', 'taken', 'unchanged', 'saving'),
    unchanged: (function() {
      return this.get('newEmail') === this.get('content.email');
    }).property('newEmail', 'content.email'),
    initializeEmail: (function() {
      return this.set('newEmail', this.get('content.email'));
    }).observes('content.email'),
    saveButtonText: (function() {
      if (this.get('saving')) {
        return Em.String.i18n("saving");
      }
      return Em.String.i18n("user.change_email.action");
    }).property('saving'),
    changeEmail: function() {
      var _this = this;
      this.set('saving', true);
      return this.get('content').changeEmail(this.get('newEmail')).then(function() {
        return _this.set('success', true);
      }, function() {
        /* Error
        */
        _this.set('error', true);
        return _this.set('saving', false);
      });
    }
  });

}).call(this);
