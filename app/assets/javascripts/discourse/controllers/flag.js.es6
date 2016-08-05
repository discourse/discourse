import ModalFunctionality from 'discourse/mixins/modal-functionality';
import ActionSummary from 'discourse/models/action-summary';
import { MAX_MESSAGE_LENGTH } from 'discourse/models/post-action-type';

export default Ember.Controller.extend(ModalFunctionality, {
  userDetails: null,
  selected: null,
  flagTopic: null,
  message: null,
  isWarning: false,
  topicActionByName: null,

  onShow() {
    this.set('selected', null);
  },

  flagsAvailable: function() {
    if (!this.get('flagTopic')) {
      // flagging post
      let flagsAvailable = this.get('model.flagsAvailable');

      // "message user" option should be at the top
      const notifyUserIndex = flagsAvailable.indexOf(flagsAvailable.filterProperty('name_key', 'notify_user')[0]);
      if (notifyUserIndex !== -1) {
        const notifyUser = flagsAvailable[notifyUserIndex];
        flagsAvailable.splice(notifyUserIndex, 1);
        flagsAvailable.splice(0, 0, notifyUser);
      }
      return flagsAvailable;
    } else {
      // flagging topic
      const self = this,
          lookup = Em.Object.create();

      _.each(this.get("model.actions_summary"),function(a) {
        a.flagTopic = self.get('model');
        a.actionType = self.site.topicFlagTypeById(a.id);
        const actionSummary = ActionSummary.create(a);
        lookup.set(a.actionType.get('name_key'), actionSummary);
      });
      this.set('topicActionByName', lookup);

      return this.site.get('topic_flag_types').filter(function(item) {
        return _.any(self.get("model.actions_summary"), function(a) {
          return (a.id === item.get('id') && a.can_act);
        });
      });
    }
  }.property('post', 'flagTopic', 'model.actions_summary.@each.can_act'),

  staffFlagsAvailable: function() {
    return (this.get('model.flagsAvailable') && this.get('model.flagsAvailable').length > 1);
  }.property('post', 'flagTopic', 'model.actions_summary.@each.can_act'),

  submitEnabled: function() {
    const selected = this.get('selected');
    if (!selected) return false;

    if (selected.get('is_custom_flag')) {
      const len = this.get('message.length') || 0;
      return len >= Discourse.SiteSettings.min_private_message_post_length &&
             len <= MAX_MESSAGE_LENGTH;
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
    takeAction() {
      this.send('createFlag', {takeAction: true});
      this.set('model.hidden', true);
    },

    createFlag(opts) {
      let postAction; // an instance of ActionSummary

      if (!this.get('flagTopic')) {
        postAction = this.get('model.actions_summary').findProperty('id', this.get('selected.id'));
      } else {
        postAction = this.get('topicActionByName.' + this.get('selected.name_key'));
      }

      let params = this.get('selected.is_custom_flag') ? {message: this.get('message') } : {};
      if (opts) { params = $.extend(params, opts); }

      this.send('hideModal');

      postAction.act(this.get('model'), params).then(() => {
        this.send('closeModal');
        if (params.message) {
          this.set('message', '');
        }
        this.appEvents.trigger('post-stream:refresh', { id: this.get('model.id') });
      }).catch(errors => {
        this.send('closeModal');
        if (errors && errors.responseText) {
          bootbox.alert($.parseJSON(errors.responseText).errors);
        } else {
          bootbox.alert(I18n.t('generic_error'));
        }
      });
    },

    createFlagAsWarning() {
      this.send('createFlag', {isWarning: true});
      this.set('model.hidden', true);
    },

    changePostActionType(action) {
      this.set('selected', action);
    },
  },

  canDeleteSpammer: function() {
    if (this.get("flagTopic")) return false;

    if (Discourse.User.currentProp('staff') && this.get('selected.name_key') === 'spam') {
      return this.get('userDetails.can_be_deleted') && this.get('userDetails.can_delete_all_posts');
    } else {
      return false;
    }
  }.property('selected.name_key', 'userDetails.can_be_deleted', 'userDetails.can_delete_all_posts'),

  canSendWarning: function() {
    if (this.get("flagTopic")) return false;

    return (Discourse.User.currentProp('staff') && this.get('selected.name_key') === 'notify_user');
  }.property('selected.name_key'),

  usernameChanged: function() {
    this.set('userDetails', null);
    this.fetchUserDetails();
  }.observes('model.username'),

  fetchUserDetails() {
    if (Discourse.User.currentProp('staff') && this.get('model.username')) {
      const AdminUser = require('admin/models/admin-user').default;
      AdminUser.find(this.get('model.user_id')).then(user => this.set('userDetails', user));
    }
  }

});
