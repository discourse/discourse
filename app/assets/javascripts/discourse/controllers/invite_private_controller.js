/**
  The modal for inviting a user to a private topic

  @class InvitePrivateController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.InvitePrivateController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  disabled: function() {
    if (this.get('saving')) return true;
    return this.blank('emailOrUsername');
  }.property('emailOrUsername', 'saving'),

  buttonTitle: function() {
    if (this.get('saving')) return Em.String.i18n('topic.inviting');
    return Em.String.i18n('topic.invite_private.action');
  }.property('saving'),

  invite: function() {

    if (this.get('disabled')) return;

    var invitePrivateController = this;
    this.set('saving', true);
    this.set('error', false);
    // Invite the user to the private message
    this.get('content').inviteUser(this.get('emailOrUsername')).then(function() {
      // Success
      invitePrivateController.set('saving', false);
      invitePrivateController.set('finished', true);
    }, function() {
      // Failure
      invitePrivateController.set('error', true);
      invitePrivateController.set('saving', false);
    });
    return false;
  }

});