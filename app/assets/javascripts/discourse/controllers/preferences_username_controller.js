/**
  This controller supports actions related to updating one's username

  @class PreferencesUsernameController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesUsernameController = Discourse.ObjectController.extend({
  taken: false,
  saving: false,
  error: false,
  errorMessage: null,

  saveDisabled: function() {
    if (this.get('saving')) return true;
    if (this.blank('newUsername')) return true;
    if (this.get('taken')) return true;
    if (this.get('unchanged')) return true;
    if (this.get('errorMessage')) return true;
    return false;
  }.property('newUsername', 'taken', 'errorMessage', 'unchanged', 'saving'),

  unchanged: function() {
    return this.get('newUsername') === this.get('content.username');
  }.property('newUsername', 'content.username'),

  checkTaken: function() {
    if( this.get('newUsername') && this.get('newUsername').length < 3 ) {
      this.set('errorMessage', Em.String.i18n('user.name.too_short'));
    } else {
      var preferencesUsernameController = this;
      this.set('taken', false);
      this.set('errorMessage', null);
      if (this.blank('newUsername')) return;
      if (this.get('unchanged')) return;
      Discourse.User.checkUsername(this.get('newUsername')).then(function(result) {
        if (result.errors) {
          preferencesUsernameController.set('errorMessage', result.errors.join(' '));
        } else if (result.available === false) {
          preferencesUsernameController.set('taken', true);
        }
      });
    }
  }.observes('newUsername'),

  saveButtonText: function() {
    if (this.get('saving')) return Em.String.i18n("saving");
    return Em.String.i18n("user.change_username.action");
  }.property('saving'),

  changeUsername: function() {
    var preferencesUsernameController = this;
    return bootbox.confirm(Em.String.i18n("user.change_username.confirm"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), function(result) {
      if (result) {
        preferencesUsernameController.set('saving', true);
        preferencesUsernameController.get('content').changeUsername(preferencesUsernameController.get('newUsername')).then(function() {
          Discourse.URL.redirectTo("/users/" + preferencesUsernameController.get('newUsername').toLowerCase() + "/preferences");
        }, function() {
          // error
          preferencesUsernameController.set('error', true);
          preferencesUsernameController.set('saving', false);
        });
      }
    });
  }
});


