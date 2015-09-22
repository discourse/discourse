import ModalFunctionality from 'discourse/mixins/modal-functionality';
import Invite from 'discourse/models/invite';

export default Ember.Controller.extend(ModalFunctionality, {
  needs: ['user-invited-show'],

  // If this isn't defined, it will proxy to the user model on the preferences
  // page which is wrong.
  emailOrUsername: null,

  isAdmin: function(){
    return Discourse.User.currentProp("admin");
  }.property(),

  disabled: function() {
    if (this.get('model.saving')) return true;
    if (Ember.isEmpty(this.get('emailOrUsername'))) return true;
    const emailOrUsername = this.get('emailOrUsername').trim();
    // when inviting to forum, email must be valid
    if (!this.get('invitingToTopic') && !Discourse.Utilities.emailValid(emailOrUsername)) return true;
    // normal users (not admin) can't invite users to private topic via email
    if (!this.get('isAdmin') && this.get('isPrivateTopic') && Discourse.Utilities.emailValid(emailOrUsername)) return true;
    // when inviting to private topic via email, group name must be specified
    if (this.get('isPrivateTopic') && Ember.isEmpty(this.get('model.groupNames')) && Discourse.Utilities.emailValid(emailOrUsername)) return true;
    if (this.get('model.details.can_invite_to')) return false;
    return false;
  }.property('isAdmin', 'emailOrUsername', 'invitingToTopic', 'isPrivateTopic', 'model.groupNames', 'model.saving'),

  disabledCopyLink: function() {
    if (this.get('model.saving')) return true;
    if (Ember.isEmpty(this.get('emailOrUsername'))) return true;
    const emailOrUsername = this.get('emailOrUsername').trim();
    // email must be valid
    if (!Discourse.Utilities.emailValid(emailOrUsername)) return true;
    // normal users (not admin) can't invite users to private topic via email
    if (!this.get('isAdmin') && this.get('isPrivateTopic') && Discourse.Utilities.emailValid(emailOrUsername)) return true;
    // when inviting to private topic via email, group name must be specified
    if (this.get('isPrivateTopic') && Ember.isEmpty(this.get('model.groupNames')) && Discourse.Utilities.emailValid(emailOrUsername)) return true;
    return false;
  }.property('emailOrUsername', 'model.saving', 'isPrivateTopic', 'model.groupNames'),

  buttonTitle: function() {
    return this.get('model.saving') ? 'topic.inviting' : 'topic.invite_reply.action';
  }.property('model.saving'),

  // We are inviting to a topic if the model isn't the current user.
  // The current user would mean we are inviting to the forum in general.
  invitingToTopic: function() {
    return this.get('model') !== this.currentUser;
  }.property('model'),

  showCopyInviteButton: function() {
    return (!Discourse.SiteSettings.enable_sso && !this.get('isMessage'));
  }.property('isMessage'),

  topicId: Ember.computed.alias('model.id'),

  // Is Private Topic? (i.e. visible only to specific group members)
  isPrivateTopic: Em.computed.and('invitingToTopic', 'model.category.read_restricted'),

  // Is Private Message?
  isMessage: Em.computed.equal('model.archetype', 'private_message'),

  // Allow Existing Members? (username autocomplete)
  allowExistingMembers: function() {
    return this.get('invitingToTopic');
  }.property('invitingToTopic'),

  // Show Groups? (add invited user to private group)
  showGroups: function() {
    return this.get('isAdmin') && (Discourse.Utilities.emailValid(this.get('emailOrUsername')) || this.get('isPrivateTopic') || !this.get('invitingToTopic')) && !Discourse.SiteSettings.enable_sso && !this.get('isMessage');
  }.property('isAdmin', 'emailOrUsername', 'isPrivateTopic', 'isMessage', 'invitingToTopic'),

  // Instructional text for the modal.
  inviteInstructions: function() {
    if (Discourse.SiteSettings.enable_sso) {
      // inviting existing user when SSO enabled
      return I18n.t('topic.invite_reply.sso_enabled');
    } else if (this.get('isMessage')) {
      // inviting to a message
      return I18n.t('topic.invite_private.email_or_username');
    } else if (this.get('invitingToTopic')) {
      // inviting to a private/public topic
      if (this.get('isPrivateTopic') && !this.get('isAdmin')) {
        // inviting to a private topic and is not admin
        return I18n.t('topic.invite_reply.to_username');
      } else {
        // when inviting to a topic, display instructions based on provided entity
        if (Ember.isEmpty(this.get('emailOrUsername'))) {
          return I18n.t('topic.invite_reply.to_topic_blank');
        } else if (Discourse.Utilities.emailValid(this.get('emailOrUsername'))) {
          return I18n.t('topic.invite_reply.to_topic_email');
        } else {
          return I18n.t('topic.invite_reply.to_topic_username');
        }
      }
    } else {
      // inviting to forum
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
    if (this.get('model.inviteLink')) {
      return I18n.t('user.invited.generated_link_message', {inviteLink: this.get('model.inviteLink'), invitedEmail: this.get('emailOrUsername')});
    } else if (this.get('isMessage')) {
      return I18n.t('topic.invite_private.success');
    } else if ( Discourse.Utilities.emailValid(this.get('emailOrUsername')) ) {
      return I18n.t('topic.invite_reply.success_email', { emailOrUsername: this.get('emailOrUsername') });
    } else {
      return I18n.t('topic.invite_reply.success_username');
    }
  }.property('model.inviteLink', 'isMessage', 'emailOrUsername'),

  errorMessage: function() {
    return this.get('isMessage') ? I18n.t('topic.invite_private.error') : I18n.t('topic.invite_reply.error');
  }.property('isMessage'),

  placeholderKey: function() {
    return Discourse.SiteSettings.enable_sso ?
            'topic.invite_reply.username_placeholder' :
            'topic.invite_private.email_or_username_placeholder';
  }.property(),

  // Reset the modal to allow a new user to be invited.
  reset() {
    this.set('emailOrUsername', null);
    this.get('model').setProperties({
      groupNames: null,
      error: false,
      saving: false,
      finished: false,
      inviteLink: null
    });
  },

  actions: {

    createInvite() {
      if (this.get('disabled')) { return; }

      const groupNames = this.get('model.groupNames'),
            userInvitedController = this.get('controllers.user-invited-show'),
            model = this.get('model');

      model.setProperties({ saving: true, error: false });

      return this.get('model').createInvite(this.get('emailOrUsername').trim(), groupNames).then(result => {
              model.setProperties({ saving: false, finished: true });
              if (!this.get('invitingToTopic')) {
                Invite.findInvitedBy(this.currentUser, userInvitedController.get('filter')).then(invite_model => {
                  userInvitedController.set('model', invite_model);
                  userInvitedController.set('totalInvites', invite_model.invites.length);
                });
              } else if (this.get('isMessage') && result && result.user) {
                this.get('model.details.allowed_users').pushObject(result.user);
              }
            }).catch(() => model.setProperties({ saving: false, error: true }));
    },

    generateInvitelink() {
      if (this.get('disabled')) { return; }

      const groupNames = this.get('model.groupNames'),
            userInvitedController = this.get('controllers.user-invited-show'),
            model = this.get('model');

      var topicId = null;
      if (this.get('invitingToTopic')) {
        topicId = this.get('model.id');
      }

      model.setProperties({ saving: true, error: false });

      return this.get('model').generateInviteLink(this.get('emailOrUsername').trim(), groupNames, topicId).then(result => {
              model.setProperties({ saving: false, finished: true, inviteLink: result });
              Invite.findInvitedBy(this.currentUser, userInvitedController.get('filter')).then(invite_model => {
                userInvitedController.set('model', invite_model);
                userInvitedController.set('totalInvites', invite_model.invites.length);
              });
            }).catch(() => model.setProperties({ saving: false, error: true }));
    }
  }

});
