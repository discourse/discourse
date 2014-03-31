/**
  A data model representing a statistic on a UserAction

  @class UserActionStat
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActionStat = Discourse.Model.extend({

  description: Discourse.computed.i18n('action_type', 'user_action_groups.%@'),

  isPM: function() {
    var actionType = this.get('action_type');
    return actionType === Discourse.UserAction.TYPES.messages_sent ||
           actionType === Discourse.UserAction.TYPES.messages_received;
  }.property('action_type'),

  isResponse: function() {
    var actionType = this.get('action_type');
    return actionType === Discourse.UserAction.TYPES.replies ||
           actionType === Discourse.UserAction.TYPES.mentions ||
           actionType === Discourse.UserAction.TYPES.quotes;
  }.property('action_type')

});
