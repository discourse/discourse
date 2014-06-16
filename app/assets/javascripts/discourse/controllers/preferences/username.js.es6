/**
  This controller supports actions related to updating one's username

  @class PreferencesUsernameController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
export default Discourse.ObjectController.extend({
  taken: false,
  saving: false,
  error: false,
  errorMessage: null,
  newUsername: null,

  newUsernameEmpty: Em.computed.empty('newUsername'),
  saveDisabled: Em.computed.or('saving', 'newUsernameEmpty', 'taken', 'unchanged', 'errorMessage'),
  unchanged: Discourse.computed.propertyEqual('newUsername', 'username'),

  checkTaken: function() {
    if( this.get('newUsername') && this.get('newUsername').length < 3 ) {
      this.set('errorMessage', I18n.t('user.name.too_short'));
    } else {
      var self = this;
      this.set('taken', false);
      this.set('errorMessage', null);
      if (this.blank('newUsername')) return;
      if (this.get('unchanged')) return;
      Discourse.User.checkUsername(this.get('newUsername'), undefined, this.get('content.id')).then(function(result) {
        if (result.errors) {
          self.set('errorMessage', result.errors.join(' '));
        } else if (result.available === false) {
          self.set('taken', true);
        }
      });
    }
  }.observes('newUsername'),

  saveButtonText: function() {
    if (this.get('saving')) return I18n.t("saving");
    return I18n.t("user.change");
  }.property('saving'),

  actions: {
    changeUsername: function() {
      var self = this;
      return bootbox.confirm(I18n.t("user.change_username.confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          self.set('saving', true);
          self.get('content').changeUsername(self.get('newUsername')).then(function() {
            Discourse.URL.redirectTo("/users/" + self.get('newUsername').toLowerCase() + "/preferences");
          }, function() {
            // error
            self.set('error', true);
            self.set('saving', false);
          });
        }
      });
    }
  }

});


