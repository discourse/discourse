/**
  The modal for inviting a user to a topic

  @class InviteController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.InviteController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  /**
    Can we submit the form?

    @property disabled
  **/
  disabled: function() {
    if (this.get('saving')) return true;
    if (this.blank('email')) return true;
    if (!Discourse.Utilities.emailValid(this.get('email'))) return true;
    return false;
  }.property('email', 'saving'),

  /**
    The current text for the invite button

    @property buttonTitle
  **/
  buttonTitle: function() {
    if (this.get('saving')) return I18n.t('topic.inviting');
    return I18n.t('topic.invite_reply.action');
  }.property('saving'),

  /**
    We are inviting to a topic if the model isn't the current user. The current user would
    mean we are inviting to the forum in general.

    @property invitingToTopic
  **/
  invitingToTopic: function() {
    return this.get('model') !== Discourse.User.current();
  }.property('model'),

  /**
    Instructional text for the modal.

    @property inviteInstructions
  **/
  inviteInstructions: function() {
    if (this.get('invitingToTopic')) {
      return I18n.t('topic.invite_reply.to_topic');
    } else {
      return I18n.t('topic.invite_reply.to_forum');
    }
  }.property('invitingToTopic'),

  /**
    The "success" text for when the invite was created.

    @property successMessage
  **/
  successMessage: function() {
    return I18n.t('topic.invite_reply.success', { email: this.get('email') });
  }.property('email'),

  /**
    Reset the modal to allow a new user to be invited.

    @method reset
  **/
  reset: function() {
    this.setProperties({
      email: null,
      error: false,
      saving: false,
      finished: false
    });
  },

  actions: {

    /**
      Create the invite and update the modal accordingly.

      @method createInvite
    **/
    createInvite: function() {

      if (this.get('disabled')) { return; }

      var self = this;
      this.setProperties({ saving: true, error: false });
      this.get('model').createInvite(this.get('email')).then(function() {
        self.setProperties({ saving: false, finished: true });
      }).catch(function() {
        self.setProperties({ saving: false, error: true });
      });
      return false;
    }
  }


});
