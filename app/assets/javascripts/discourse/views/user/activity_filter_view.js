/**
  This view handles rendering of an activity in a user's profile

  @class ActivityFilterView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ActivityFilterView = Discourse.View.extend({
  tagName: 'li',
  classNameBindings: ['active', 'noGlyph'],

  userActionType: Em.computed.alias('controller.userActionType'),
  shouldRerender: Discourse.View.renderIfChanged('count'),
  noGlyph: Em.computed.empty('icon'),

  active: function() {
    var content = this.get('content');
    if (content) {
      return parseInt(this.get('userActionType'), 10) === parseInt(Em.get(content, 'action_type'), 10);
    } else {
      return this.blank('userActionType');
    }
  }.property('userActionType', 'content.action_type'),

  activityCount: function() {
    return this.get('content.count') || this.get('count');
  }.property('content.count', 'count'),

  typeKey: function() {

    var actionType = this.get('content.action_type');
    if (actionType === Discourse.UserAction.TYPES.messages_received) { return ""; }

    var result = Discourse.UserAction.TYPES_INVERTED[actionType];
    if (!result) { return ""; }

    // We like our URLS to have hyphens, not underscores
    return "/" + result.replace("_", "-");
  }.property('content.action_type'),

  url: function() {
    var section = this.get('content.isPM') ? "/private-messages" : "/activity";
    return "/users/" + this.get('user.username_lower') + section + this.get('typeKey');
  }.property('typeKey'),

  description: function() {
    return this.get('content.description') || I18n.t("user.filters.all");
  }.property('content.description'),

  render: function(buffer) {
    buffer.push("<a href='" + this.get('url') + "'>");
    var icon = this.get('icon');
    if (icon) {
      buffer.push("<i class='glyph icon icon-" + icon + "'></i> ");
    }

    buffer.push(this.get('description') + " <span class='count'>(" + this.get('activityCount') + ")</span>");
    buffer.push("<span class='icon-chevron-right'></span></a>");
  },

  icon: function(){
    switch(parseInt(this.get('content.action_type'),10)) {
      case Discourse.UserAction.TYPES.likes_received:
        return "heart";
      case Discourse.UserAction.TYPES.bookmarks:
        return "bookmark";
      case Discourse.UserAction.TYPES.edits:
        return "pencil";
      case Discourse.UserAction.TYPES.replies:
        return "reply";
      case Discourse.UserAction.TYPES.favorites:
        return "star";
    }
  }.property("content.action_type")

});

Discourse.View.registerHelper('activityFilter', Discourse.ActivityFilterView);
