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

  /**
    Can we submit the form?

    @property disabled
  **/
  disabled: function() {
    if (this.get('saving')) return true;
    if (this.blank('emailOrUsername')) return true;
    if ( !this.get('invitingToTopic') && !Discourse.Utilities.emailValid(this.get('emailOrUsername')) ) return true;
    if (this.get('model.details.can_invite_to')) return false;
    if (this.get('isPrivateTopic') && this.blank('groupNames')) return true;
    return false;
  }.property('emailOrUsername', 'invitingToTopic', 'isPrivateTopic', 'groupNames', 'saving'),

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
  isPrivateTopic: Em.computed.and('invitingToTopic', 'model.category.read_restricted'),

  /**
    Is Message?

    @property isMessage
  **/
  isMessage: Em.computed.equal('model.archetype', 'private_message'),

  /**
    Allow Existing Members? (username autocomplete)

    @property allowExistingMembers
  **/
  allowExistingMembers: function() {
    return this.get('invitingToTopic') && !this.get('isPrivateTopic');
  }.property('invitingToTopic', 'isPrivateTopic'),

  /**
    Show Groups? (add invited user to private group)

    @property showGroups
  **/
  showGroups: function() {
    return this.get('isAdmin') && (Discourse.Utilities.emailValid(this.get('emailOrUsername')) || this.get('isPrivateTopic') || !this.get('invitingToTopic'));
  }.property('isAdmin', 'emailOrUsername', 'isPrivateTopic', 'invitingToTopic'),

  /**
    Instructional text for the modal.

    @property inviteInstructions
  **/
  inviteInstructions: function() {
    if (this.get('isMessage')) {
      return I18n.t('topic.invite_private.email_or_username');
    } else if (this.get('invitingToTopic')) {
      return I18n.t('topic.invite_reply.to_topic');
    } else {
      return I18n.t('topic.invite_reply.to_forum');
    }
  }.property('isMessage', 'invitingToTopic'),

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
    Function to find groups.
  **/
  groupFinder: function(term) {
    return Discourse.Group.findAll({search: term, ignore_automatic: true});
  },

  /**
    The "success" text for when the invite was created.

    @property successMessage
  **/
  successMessage: function() {
    if (this.get('isMessage')) {
      return I18n.t('topic.invite_private.success');
    } else {
      return I18n.t('topic.invite_reply.success', { emailOrUsername: this.get('emailOrUsername') });
    }
  }.property('isMessage', 'emailOrUsername'),

  /**
    The "error" text for when the invite fails.

    @property errorMessage
  **/
  errorMessage: function() {
    if (this.get('isMessage')) {
      return I18n.t('topic.invite_private.error');
    } else {
      return I18n.t('topic.invite_reply.error');
    }
  }.property('isMessage'),

  /**
    Reset the modal to allow a new user to be invited.

    @method reset
  **/
  reset: function() {
    this.setProperties({
      emailOrUsername: null,
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
      this.get('model').createInvite(this.get('emailOrUsername'), groupNames).then(function(result) {
        self.setProperties({ saving: false, finished: true });
        if (!self.get('invitingToTopic')) {
          Discourse.Invite.findInvitedBy(Discourse.User.current()).then(function (invite_model) {
            userInvitedController.set('model', invite_model);
            userInvitedController.set('totalInvites', invite_model.invites.length);
          });
        } else if (self.get('isMessage') && result && result.user) {
          self.get('model.details.allowed_users').pushObject(result.user);
        }
      }).catch(function() {
        self.setProperties({ saving: false, error: true });
      });
      return false;
    }
  }


});
