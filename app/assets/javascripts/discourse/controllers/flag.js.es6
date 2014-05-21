/**
  This controller supports actions related to flagging

  @class FlagController
  @extends Discourse.ObjectController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
export default Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  onShow: function() {
    this.set('selected', null);
  },

  flagsAvailable: function() {
    if (!this.get('flagTopic')) {
      return this.get('model.flagsAvailable');
    } else {
      var self = this,
          lookup = Em.Object.create();

      _.each(this.get("actions_summary"),function(a) {
        var actionSummary;
        a.flagTopic = self.get('model');
        a.actionType = Discourse.Site.current().topicFlagTypeById(a.id);
        actionSummary = Discourse.ActionSummary.create(a);
        lookup.set(a.actionType.get('name_key'), actionSummary);
      });
      this.set('topicActionByName', lookup);

      return Discourse.Site.currentProp('topic_flag_types').filter(function(item) {
        return _.any(self.get("actions_summary"), function(a) {
          return (a.id === item.get('id') && a.can_act);
        });
      });
    }
  }.property('post', 'flagTopic', 'actions_summary.@each.can_act'),

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
    if (this.get("flagTopic")) return false;

    // We can only take actions on non-custom flags
    if (this.get('selected.is_custom_flag')) return false;
    return Discourse.User.currentProp('staff');
  }.property('selected.is_custom_flag'),

  submitText: function(){
    if (this.get('selected.is_custom_flag')) {
      return "<i class='fa fa-envelope'></i>" + (I18n.t(this.get('flagTopic') ? "flagging_topic.notify_action" : "flagging.notify_action"));
    } else {
      return "<i class='fa fa-flag'></i>" + (I18n.t(this.get('flagTopic') ? "flagging_topic.action" : "flagging.action"));
    }
  }.property('selected.is_custom_flag'),

  actions: {
    takeAction: function() {
      this.send('createFlag', {takeAction: true});
      this.set('hidden', true);
    },

    createFlag: function(opts) {
      var self = this;
      var postAction; // an instance of ActionSummary
      if (!this.get('flagTopic')) {
        postAction = this.get('actionByName.' + this.get('selected.name_key'));
      } else {
        postAction = this.get('topicActionByName.' + this.get('selected.name_key'));
      }
      var params = this.get('selected.is_custom_flag') ? {message: this.get('message')} : {};

      if (opts) params = $.extend(params, opts);

      this.send('hideModal');
      postAction.act(params).then(function() {
        self.send('closeModal');
      }, function(errors) {
        self.send('closeModal');
        if (errors && errors.responseText) {
          bootbox.alert($.parseJSON(errors.responseText).errors);
        } else {
          bootbox.alert(I18n.t('generic_error'));
        }
      });
    },

    changePostActionType: function(action) {
      this.set('selected', action);
    }
  },

  canDeleteSpammer: function() {
    if (this.get("flagTopic")) return false;

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
