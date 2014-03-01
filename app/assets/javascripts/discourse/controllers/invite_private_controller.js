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

  actions: {
    invite: function() {
      if (this.get('disabled')) return;

      var self = this;
      this.setProperties({saving: true, error: false});

      // Invite the user to the private message
      this.get('model').createInvite(this.get('emailOrUsername')).then(function(result) {
        self.setProperties({saving: true, finished: true});

        if(result && result.user) {
          self.get('model.details.allowed_users').pushObject(result.user);
        }
      }).catch(function() {
        self.setProperties({error: true, saving: false});
      });
      return false;
    }
  }

});
