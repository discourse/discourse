import ModalFunctionality from 'discourse/mixins/modal-functionality';
import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend(ModalFunctionality, {
  needs: ['user-invited'],

  // If this isn't defined, it will proxy to the user model on the preferences
  // page which is wrong.
  emailOrUsername: null,

  isAdmin: function(){
    return Discourse.User.currentProp("admin");
  }.property(),

  disabled: function() {
    if (this.get('saving')) return true;
    if (this.blank('emailOrUsername')) return true;
    if (!this.get('invitingToTopic') && !Discourse.Utilities.emailValid(this.get('emailOrUsername'))) return true;
    if (this.get('model.details.can_invite_to')) return false;
    if (this.get('isPrivateTopic') && this.blank('groupNames')) return true;
    return false;
  }.property('emailOrUsername', 'invitingToTopic', 'isPrivateTopic', 'groupNames', 'saving'),

  buttonTitle: function() {
    return this.get('saving') ? I18n.t('topic.inviting') : I18n.t('topic.invite_reply.action');
  }.property('saving'),

  // We are inviting to a topic if the model isn't the current user.
  // The current user would mean we are inviting to the forum in general.
  invitingToTopic: function() {
    return this.get('model') !== Discourse.User.current();
  }.property('model'),

  // Is Private Topic? (i.e. visible only to specific group members)
  isPrivateTopic: Em.computed.and('invitingToTopic', 'model.category.read_restricted'),

  isMessage: Em.computed.equal('model.archetype', 'private_message'),

  // Allow Existing Members? (username autocomplete)
  allowExistingMembers: function() {
    return this.get('invitingToTopic') && !this.get('isPrivateTopic');
  }.property('invitingToTopic', 'isPrivateTopic'),

  // Show Groups? (add invited user to private group)
  showGroups: function() {
    return this.get('isAdmin') && (Discourse.Utilities.emailValid(this.get('emailOrUsername')) || this.get('isPrivateTopic') || !this.get('invitingToTopic'));
  }.property('isAdmin', 'emailOrUsername', 'isPrivateTopic', 'invitingToTopic'),

  // Instructional text for the modal.
  inviteInstructions: function() {
    if (this.get('isMessage')) {
      return I18n.t('topic.invite_private.email_or_username');
    } else if (this.get('invitingToTopic')) {
      // display instructions based on provided entity
      if (this.blank('emailOrUsername')) {
        return I18n.t('topic.invite_reply.to_topic_blank');
      } else if (Discourse.Utilities.emailValid(this.get('emailOrUsername'))) {
        return I18n.t('topic.invite_reply.to_topic_email');
      } else {
        return I18n.t('topic.invite_reply.to_topic_username');
      }
    } else {
      return I18n.t('topic.invite_reply.to_forum');
    }
  }.property('isMessage', 'invitingToTopic', 'emailOrUsername'),

  // Instructional text for the group selection.
  groupInstructions: function() {
    return this.get('isPrivateTopic') ?
            I18n.t('topic.automatically_add_to_groups_required') :
            I18n.t('topic.automatically_add_to_groups_optional');
  }.property('isPrivateTopic'),

  groupFinder(term) {
    return Discourse.Group.findAll({search: term, ignore_automatic: true});
  },

  successMessage: function() {
    return this.get('isMessage') ?
            I18n.t('topic.invite_private.success') :
            I18n.t('topic.invite_reply.success', { emailOrUsername: this.get('emailOrUsername') });
  }.property('isMessage', 'emailOrUsername'),

  errorMessage: function() {
    return this.get('isMessage') ? I18n.t('topic.invite_private.error') : I18n.t('topic.invite_reply.error');
  }.property('isMessage'),

  // Reset the modal to allow a new user to be invited.
  reset() {
    this.setProperties({
      emailOrUsername: null,
      groupNames: null,
      error: false,
      saving: false,
      finished: false
    });
  },

  actions: {

    createInvite() {
      if (this.get('disabled')) { return; }

      const groupNames = this.get('groupNames'),
            userInvitedController = this.get('controllers.user-invited');

      this.setProperties({ saving: true, error: false });

      return this.get('model').createInvite(this.get('emailOrUsername'), groupNames).then(result => {
              this.setProperties({ saving: false, finished: true });
              if (!this.get('invitingToTopic')) {
                Discourse.Invite.findInvitedBy(Discourse.User.current()).then(invite_model => {
                  userInvitedController.set('model', invite_model);
                  userInvitedController.set('totalInvites', invite_model.invites.length);
                });
              } else if (this.get('isMessage') && result && result.user) {
                this.get('model.details.allowed_users').pushObject(result.user);
              }
            }).catch(() => this.setProperties({ saving: false, error: true }));
    }
  }

});
