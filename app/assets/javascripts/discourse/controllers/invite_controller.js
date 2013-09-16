/**
  The modal for inviting a user to a topic

  @class InviteController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.InviteController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  disabled: function() {
    if (this.get('saving')) return true;
    if (this.blank('email')) return true;
    if (!Discourse.Utilities.emailValid(this.get('email'))) return true;
    return false;
  }.property('email', 'saving'),

  buttonTitle: function() {
    if (this.get('saving')) return I18n.t('topic.inviting');
    return I18n.t('topic.invite_reply.action');
  }.property('saving'),

  successMessage: function() {
    return I18n.t('topic.invite_reply.success', { email: this.get('email') });
  }.property('email'),

  actions: {
    createInvite: function() {
      if (this.get('disabled')) return;

      var inviteController = this;
      this.set('saving', true);
      this.set('error', false);
      this.get('model').inviteUser(this.get('email')).then(function() {
        // Success
        inviteController.set('saving', false);
        return inviteController.set('finished', true);
      }, function() {
        // Failure
        inviteController.set('error', true);
        return inviteController.set('saving', false);
      });
      return false;
    }
  }


});
