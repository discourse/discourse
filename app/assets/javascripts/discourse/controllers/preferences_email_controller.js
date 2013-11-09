/**
  This controller supports actions related to updating one's email address

  @class PreferencesEmailController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesEmailController = Discourse.ObjectController.extend({
  taken: false,
  saving: false,
  error: false,
  success: false,
  newEmail: null,

  newEmailEmpty: Em.computed.empty('newEmail'),
  saveDisabled: Em.computed.or('saving', 'newEmailEmpty', 'taken', 'unchanged'),
  unchanged: Discourse.computed.propertyEqual('newEmail', 'email'),

  saveButtonText: function() {
    if (this.get('saving')) return I18n.t("saving");
    return I18n.t("user.change");
  }.property('saving'),

  actions: {
    changeEmail: function() {
      var self = this;
      this.set('saving', true);
      return this.get('content').changeEmail(this.get('newEmail')).then(function() {
        self.set('success', true);
      }, function() {
        self.setProperties({ error: true, saving: false });
      });
    }
  }

});


