/**
  This controller supports actions related to flagging

  @class FlagController
  @extends Discourse.ObjectController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.FlagController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  onShow: function() {
    this.set('selected', null);
  },

  submitEnabled: function() {
    var selected = this.get('selected');
    if (!selected) return false;

    if (selected.get('is_custom_flag')) {
      var len = this.get('message.length') || 0;
      return len >= Discourse.SiteSettings.min_private_message_post_length &&
             len <= Discourse.PostActionType.MAX_MESSAGE_LENGTH;
    }
    return true;
  }.property('selected.is_custom_flag', 'message.length'),

  submitDisabled: Em.computed.not('submitEnabled'),

  // Staff accounts can "take action"
  canTakeAction: function() {
    // We can only take actions on non-custom flags
    if (this.get('selected.is_custom_flag')) return false;
    return Discourse.User.currentProp('staff');
  }.property('selected.is_custom_flag'),

  submitText: function(){
    if (this.get('selected.is_custom_flag')) {
      return I18n.t("flagging.notify_action");
    } else {
      return I18n.t("flagging.action");
    }
  }.property('selected.is_custom_flag'),

  actions: {
    takeAction: function() {
      this.send('createFlag', {takeAction: true});
      this.set('hidden', true);
    },

    createFlag: function(opts) {
      var self = this;
      var postAction = this.get('actionByName.' + this.get('selected.name_key'));
      var params = this.get('selected.is_custom_flag') ? {message: this.get('message')} : {};

      if (opts) params = $.extend(params, opts);

      this.send('hideModal');
      postAction.act(params).then(function() {
        self.send('closeModal');
      }, function(errors) {
        self.send('showModal');
        self.displayErrors(errors);
      });
    },

    changePostActionType: function(action) {
      this.set('selected', action);
    }
  },

  canDeleteSpammer: function() {
    if (Discourse.User.currentProp('staff') && this.get('selected.name_key') === 'spam') {
      return this.get('userDetails.can_be_deleted') && this.get('userDetails.can_delete_all_posts');
    } else {
      return false;
    }
  }.property('selected.name_key', 'userDetails.can_be_deleted', 'userDetails.can_delete_all_posts'),

  deleteSpammer: function() {
    this.send('closeModal');
    this.get('userDetails').deleteAsSpammer(function() { window.location.reload(); });
  },

  usernameChanged: function() {
    this.set('userDetails', null);
    this.fetchUserDetails();
  }.observes('username'),

  fetchUserDetails: function() {
    if( Discourse.User.currentProp('staff') && this.get('username') ) {
      var flagController = this;
      Discourse.AdminUser.find(this.get('username').toLowerCase()).then(function(user){
        flagController.set('userDetails', user);
      });
    }
  }

});
