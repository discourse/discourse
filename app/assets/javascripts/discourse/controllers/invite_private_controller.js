/**
  The modal for inviting a user to a private topic

  @class InvitePrivateController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.InvitePrivateController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  modalClass: 'invite',

  onShow: function(){
    this.set('controllers.modal.modalClass', 'invite-modal');
    this.set('emailOrUsername', '');
  },

  disabled: function() {
    if (this.get('saving')) return true;
    return this.blank('emailOrUsername');
  }.property('emailOrUsername', 'saving'),

  buttonTitle: function() {
    if (this.get('saving')) return I18n.t('topic.inviting');
    return I18n.t('topic.invite_private.action');
  }.property('saving'),

  invite: function() {

    if (this.get('disabled')) return;

    var invitePrivateController = this;
    this.set('saving', true);
    this.set('error', false);
    // Invite the user to the private message
    this.get('content').inviteUser(this.get('emailOrUsername')).then(function(result) {
      // Success
      invitePrivateController.set('saving', false);
      invitePrivateController.set('finished', true);

      if(result && result.user) {
        invitePrivateController.get('content.details.allowed_users').pushObject(result.user);
      }
    }, function() {
      // Failure
      invitePrivateController.set('error', true);
      invitePrivateController.set('saving', false);
    });
    return false;
  }

});
