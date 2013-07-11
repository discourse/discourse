/**
  A data model representing a statistic on a UserAction

  @class UserActionStat
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActionStat = Discourse.Model.extend({

  isPM: function() {
    var actionType = this.get('action_type');
    return actionType === Discourse.UserAction.NEW_PRIVATE_MESSAGE ||
           actionType === Discourse.UserAction.GOT_PRIVATE_MESSAGE;
  }.property('action_type'),

  description: function() {
    return I18n.t('user_action_groups.' + this.get('action_type'));
  }.property('description'),

  isResponse: function() {
    var actionType = this.get('action_type');
    return actionType === Discourse.UserAction.RESPONSE ||
           actionType === Discourse.UserAction.MENTION ||
           actionType === Discourse.UserAction.QUOTE;
  }.property('action_type')

});


