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

  saveDisabled: (function() {
    if (this.get('saving')) return true;
    if (this.blank('newEmail')) return true;
    if (this.get('taken')) return true;
    if (this.get('unchanged')) return true;
  }).property('newEmail', 'taken', 'unchanged', 'saving'),

  unchanged: (function() {
    return this.get('newEmail') === this.get('content.email');
  }).property('newEmail', 'content.email'),

  initializeEmail: (function() {
    this.set('newEmail', this.get('content.email'));
  }).observes('content.email'),

  saveButtonText: (function() {
    if (this.get('saving')) return I18n.t("saving");
    return I18n.t("user.change_email.action");
  }).property('saving'),

  changeEmail: function() {
    var preferencesEmailController = this;
    this.set('saving', true);
    return this.get('content').changeEmail(this.get('newEmail')).then(function() {
      preferencesEmailController.set('success', true);
    }, function() {
      // Error
      preferencesEmailController.set('error', true);
      preferencesEmailController.set('saving', false);
    });
  }

});


