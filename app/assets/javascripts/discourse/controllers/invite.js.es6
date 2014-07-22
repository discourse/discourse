/**
  The modal for inviting a user to a topic

  @class InviteController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
export default Discourse.ObjectController.extend(Discourse.ModalFunctionality, {
  needs: ['user-invited'],

  isAdmin: function(){
    return Discourse.User.currentProp("admin");
  }.property(),

  /**
    Can we submit the form?

    @property disabled
  **/
  disabled: function() {
    if (this.get('saving')) return true;
    if (this.blank('email')) return true;
    if (!Discourse.Utilities.emailValid(this.get('email'))) return true;
    if (this.get('isPrivateTopic') && this.blank('groupNames')) return true;
    return false;
  }.property('email', 'isPrivateTopic', 'groupNames', 'saving'),

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
    Is Private Topic? (i.e. visible only to specific group members) 

    @property isPrivateTopic
  **/
  isPrivateTopic: function() {    
    return this.get('invitingToTopic') && this.get('model.category.read_restricted');
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
    Instructional text for the group selection.

    @property groupInstructions
  **/
  groupInstructions: function() {
    if (this.get('isPrivateTopic')) {
      return I18n.t('topic.automatically_add_to_groups_required');
    } else {
      return I18n.t('topic.automatically_add_to_groups_optional');
    }
  }.property('isPrivateTopic'),

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
      groupNames: null,
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
      var groupNames = this.get('groupNames');
      var userInvitedController = this.get('controllers.user-invited');

      this.setProperties({ saving: true, error: false });
      this.get('model').createInvite(this.get('email'), groupNames).then(function() {
        self.setProperties({ saving: false, finished: true });
        if (!self.get('invitingToTopic')) {
          Discourse.Invite.findInvitedBy(Discourse.User.current()).then(function (invite_model) {
            userInvitedController.set('model', invite_model);
            userInvitedController.set('totalInvites', invite_model.invites.length);
          });
        }
      }).catch(function() {
        self.setProperties({ saving: false, error: true });
      });
      return false;
    }
  }


});
