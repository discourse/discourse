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

  saveDisabled: (function() {
    if (this.get('saving')) return true;
    if (this.blank('newUsername')) return true;
    if (this.get('taken')) return true;
    if (this.get('unchanged')) return true;
    if (this.get('errorMessage')) return true;
    return false;
  }).property('newUsername', 'taken', 'errorMessage', 'unchanged', 'saving'),

  unchanged: (function() {
    return this.get('newUsername') === this.get('content.username');
  }).property('newUsername', 'content.username'),

  checkTaken: (function() {
    if( this.get('newUsername') && this.get('newUsername').length < 3 ) {
      this.set('errorMessage', Em.String.i18n('user.name.too_short'));
    } else {
      var _this = this;
      this.set('taken', false);
      this.set('errorMessage', null);
      if (this.blank('newUsername')) return;
      if (this.get('unchanged')) return;
      Discourse.User.checkUsername(this.get('newUsername')).then(function(result) {
        if (result.errors) {
          return _this.set('errorMessage', result.errors.join(' '));
        } else if (result.available === false) {
          return _this.set('taken', true);
        }
      });
    }
  }).observes('newUsername'),

  saveButtonText: (function() {
    if (this.get('saving')) return Em.String.i18n("saving");
    return Em.String.i18n("user.change_username.action");
  }).property('saving'),

  changeUsername: function() {
    var _this = this;
    return bootbox.confirm(Em.String.i18n("user.change_username.confirm"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), function(result) {
      if (result) {
        _this.set('saving', true);
        return _this.get('content').changeUsername(_this.get('newUsername')).then(function() {
          var url = Discourse.getURL("/users/") + _this.get('newUsername').toLowerCase() + "/preferences";
          Discourse.URL.redirectTo(url);
        }, function() {
          // error
          _this.set('error', true);
          _this.set('saving', false);
        });
      }
    });
  }
});


