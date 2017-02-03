import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { emailValid } from 'discourse/lib/utilities';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend(ModalFunctionality, {
  userInvitedShow: Ember.inject.controller('user-invited-show'),

  // If this isn't defined, it will proxy to the user model on the preferences
  // page which is wrong.
  emailOrUsername: null,
  hasCustomMessage: false,
  customMessage: null,
  inviteIcon: "envelope",

  @computed('isMessage', 'invitingToTopic')
  title(isMessage, invitingToTopic) {
    if (isMessage) {
      return 'topic.invite_private.title';
    } else if (invitingToTopic) {
      return 'topic.invite_reply.title';
    } else {
      return 'user.invited.create';
    }
  },

  isAdmin: function(){
    return Discourse.User.currentProp("admin");
  }.property(),

  @computed('isAdmin', 'emailOrUsername', 'invitingToTopic', 'isPrivateTopic', 'model.groupNames', 'model.saving', 'model.details.can_invite_to')
  disabled(isAdmin, emailOrUsername, invitingToTopic, isPrivateTopic, groupNames, saving, can_invite_to) {
    if (saving) return true;
    if (Ember.isEmpty(emailOrUsername)) return true;
    const emailTrimmed = emailOrUsername.trim();

    // when inviting to forum, email must be valid
    if (!invitingToTopic && !emailValid(emailTrimmed)) return true;
    // normal users (not admin) can't invite users to private topic via email
    if (!isAdmin && isPrivateTopic && emailValid(emailTrimmed)) return true;
    // when inviting to private topic via email, group name must be specified
    if (isPrivateTopic && Ember.isEmpty(groupNames) && emailValid(emailTrimmed)) return true;

    if (can_invite_to) return false;
    return false;
  },

  disabledCopyLink: function() {
    if (this.get('hasCustomMessage')) return true;
    if (this.get('model.saving')) return true;
    if (Ember.isEmpty(this.get('emailOrUsername'))) return true;
    const emailOrUsername = this.get('emailOrUsername').trim();
    // email must be valid
    if (!emailValid(emailOrUsername)) return true;
    // normal users (not admin) can't invite users to private topic via email
    if (!this.get('isAdmin') && this.get('isPrivateTopic') && emailValid(emailOrUsername)) return true;
    // when inviting to private topic via email, group name must be specified
    if (this.get('isPrivateTopic') && Ember.isEmpty(this.get('model.groupNames')) && emailValid(emailOrUsername)) return true;
    return false;
  }.property('emailOrUsername', 'model.saving', 'isPrivateTopic', 'model.groupNames', 'hasCustomMessage'),

  buttonTitle: function() {
    return this.get('model.saving') ? 'topic.inviting' : 'topic.invite_reply.action';
  }.property('model.saving'),

  // We are inviting to a topic if the model isn't the current user.
  // The current user would mean we are inviting to the forum in general.
  invitingToTopic: function() {
    return this.get('model') !== this.currentUser;
  }.property('model'),

  @computed('model', 'model.details.can_invite_via_email')
  canInviteViaEmail(model, can_invite_via_email) {
    return (this.get('model') === this.currentUser) ?
            true :
            can_invite_via_email;
  },

  @computed('isMessage', 'canInviteViaEmail')
  showCopyInviteButton(isMessage, canInviteViaEmail) {
    return (canInviteViaEmail && !isMessage);
  },

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
  @computed('isAdmin', 'emailOrUsername', 'isPrivateTopic', 'isMessage', 'invitingToTopic', 'canInviteViaEmail')
  showGroups(isAdmin, emailOrUsername, isPrivateTopic, isMessage, invitingToTopic, canInviteViaEmail) {
    return isAdmin &&
           canInviteViaEmail &&
           !isMessage &&
           (emailValid(emailOrUsername) || isPrivateTopic || !invitingToTopic);
  },

  @computed('emailOrUsername')
  showCustomMessage(emailOrUsername) {
    return (this.get('model') === this.currentUser || emailValid(emailOrUsername));
  },

  // Instructional text for the modal.
  @computed('isMessage', 'invitingToTopic', 'emailOrUsername', 'isPrivateTopic', 'isAdmin', 'canInviteViaEmail')
  inviteInstructions(isMessage, invitingToTopic, emailOrUsername, isPrivateTopic, isAdmin, canInviteViaEmail) {
    if (!canInviteViaEmail) {
      // can't invite via email, only existing users
      return I18n.t('topic.invite_reply.sso_enabled');
    } else if (isMessage) {
      // inviting to a message
      return I18n.t('topic.invite_private.email_or_username');
    } else if (invitingToTopic) {
      // inviting to a private/public topic
      if (isPrivateTopic && !isAdmin) {
        // inviting to a private topic and is not admin
        return I18n.t('topic.invite_reply.to_username');
      } else {
        // when inviting to a topic, display instructions based on provided entity
        if (Ember.isEmpty(emailOrUsername)) {
          return I18n.t('topic.invite_reply.to_topic_blank');
        } else if (emailValid(emailOrUsername)) {
          this.set("inviteIcon", "envelope");
          return I18n.t('topic.invite_reply.to_topic_email');
        } else {
          this.set("inviteIcon", "hand-o-right");
          return I18n.t('topic.invite_reply.to_topic_username');
        }
      }
    } else {
      // inviting to forum
      return I18n.t('topic.invite_reply.to_forum');
    }
  },

  showGroupsClass: function() {
    return this.get('isPrivateTopic') ? 'required' : 'optional';
  }.property('isPrivateTopic'),

  groupFinder(term) {
    const Group = require('discourse/models/group').default;
    return Group.findAll({search: term, ignore_automatic: true});
  },

  successMessage: function() {
    if (this.get('hasGroups')) {
      return I18n.t('topic.invite_private.success_group');
    } else if (this.get('isMessage')) {
      return I18n.t('topic.invite_private.success');
    } else if ( emailValid(this.get('emailOrUsername')) ) {
      return I18n.t('topic.invite_reply.success_email', { emailOrUsername: this.get('emailOrUsername') });
    } else {
      return I18n.t('topic.invite_reply.success_username');
    }
  }.property('model.inviteLink', 'isMessage', 'emailOrUsername'),

  errorMessage: function() {
    return this.get('isMessage') ? I18n.t('topic.invite_private.error') : I18n.t('topic.invite_reply.error');
  }.property('isMessage'),

  @computed('canInviteViaEmail')
  placeholderKey(canInviteViaEmail) {
    return (canInviteViaEmail) ?
            'topic.invite_private.email_or_username_placeholder' :
            'topic.invite_reply.username_placeholder';
  },

  customMessagePlaceholder: function() {
    return I18n.t('invite.custom_message_placeholder');
  }.property(),

  // Reset the modal to allow a new user to be invited.
  reset() {
    this.set('emailOrUsername', null);
    this.set('hasCustomMessage', false);
    this.set('customMessage', null);
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
      const Invite = require('discourse/models/invite').default;
      const self = this;

      if (this.get('disabled')) { return; }

      const groupNames = this.get('model.groupNames'),
            userInvitedController = this.get('userInvitedShow'),
            model = this.get('model');

      model.setProperties({ saving: true, error: false });

      const onerror = function(e) {
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
          self.set("errorMessage", e.jqXHR.responseJSON.errors[0]);
        } else {
          self.set("errorMessage", self.get('isMessage') ? I18n.t('topic.invite_private.error') : I18n.t('topic.invite_reply.error'));
        }
        model.setProperties({ saving: false, error: true });
      };

      if (this.get('hasGroups')) {
        return this.get('model').createGroupInvite(this.get('emailOrUsername').trim()).then((data) => {
          model.setProperties({ saving: false, finished: true });
          this.get('model.details.allowed_groups').pushObject(Ember.Object.create(data.group));
          this.appEvents.trigger('post-stream:refresh');

        }).catch(onerror);

      } else {

        return this.get('model').createInvite(this.get('emailOrUsername').trim(), groupNames, this.get('customMessage')).then(result => {
              model.setProperties({ saving: false, finished: true });
              if (!this.get('invitingToTopic')) {
                Invite.findInvitedBy(this.currentUser, userInvitedController.get('filter')).then(invite_model => {
                  userInvitedController.set('model', invite_model);
                  userInvitedController.set('totalInvites', invite_model.invites.length);
                });
              } else if (this.get('isMessage') && result && result.user) {
                this.get('model.details.allowed_users').pushObject(Ember.Object.create(result.user));
                this.appEvents.trigger('post-stream:refresh');
              }
            }).catch(onerror);
      }
    },

    generateInvitelink() {
      const Invite = require('discourse/models/invite').default;
      const self = this;

      if (this.get('disabled')) { return; }

      const groupNames = this.get('model.groupNames'),
            userInvitedController = this.get('userInvitedShow'),
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
            }).catch(function(e) {
              if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
                self.set("errorMessage", e.jqXHR.responseJSON.errors[0]);
              } else {
                self.set("errorMessage", self.get('isMessage') ? I18n.t('topic.invite_private.error') : I18n.t('topic.invite_reply.error'));
              }
              model.setProperties({ saving: false, error: true });
            });
    },

    showCustomMessageBox() {
      this.toggleProperty('hasCustomMessage');
      if (this.get('hasCustomMessage')) {
        if (this.get('model') === this.currentUser) {
          this.set('customMessage', I18n.t('invite.custom_message_template_forum'));
        } else {
          this.set('customMessage', I18n.t('invite.custom_message_template_topic'));
        }
      } else {
        this.set('customMessage', null);
      }
    }
  }

});
