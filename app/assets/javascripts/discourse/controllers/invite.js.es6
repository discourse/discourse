import ModalFunctionality from 'discourse/mixins/modal-functionality';
import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend(ModalFunctionality, {
  needs: ['user-invited'],

  // If this isn't defined, it will proxy to the user model on the preferences
  // page which is wrong.
  email: null,

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
    if (this.get('model.details.can_invite_to')) return false;
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
  isPrivateTopic: Em.computed.and('invitingToTopic', 'model.category.read_restricted'),

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
