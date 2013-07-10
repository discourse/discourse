/**
  This view handles rendering of an activity in a user's stream

  @class ActivityFilterView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ActivityFilterView = Discourse.View.extend({
  tagName: 'li',
  classNameBindings: ['active', 'noGlyph'],

  stream: Em.computed.alias('controller.content'),
  shouldRerender: Discourse.View.renderIfChanged('count'),

  noGlyph: Em.computed.empty('icon'),

  active: function() {
    var content = this.get('content');
    if (content) {
      return parseInt(this.get('stream.filter'), 10) === parseInt(Em.get(content, 'action_type'), 10);
    } else {
      return this.blank('stream.filter');
    }
  }.property('stream.filter', 'content.action_type'),

  render: function(buffer) {
    var content = this.get("content");
    var count, description;

    if (content) {
      count = Em.get(content, "count");
      description = Em.get(content, "description");
    } else {
      count = this.get("count");
      description = I18n.t("user.filters.all");
    }

    var icon = this.get('icon');
    if(icon) {
      buffer.push("<i class='glyph icon icon-" + icon + "'></i>");
    }

    buffer.push("<a href='#'>" + description +
        " <span class='count'>(" + count + ")</span>");


    buffer.push("<span class='icon-chevron-right'></span></a>");

  },

  icon: function(){
    var action_type = parseInt(this.get("content.action_type"),10);
    var icon;

    switch(action_type){
      case Discourse.UserAction.WAS_LIKED:
        icon = "heart";
        break;
      case Discourse.UserAction.BOOKMARK:
        icon = "bookmark";
        break;
      case Discourse.UserAction.EDIT:
        icon = "pencil";
        break;
      case Discourse.UserAction.RESPONSE:
        icon = "reply";
        break;
      case Discourse.UserAction.STAR:
        icon = "star";
        break;
    }

    return icon;
  }.property("content.action_type"),

  click: function() {
    this.set('stream.filter', this.get('content.action_type'));
    return false;
  }
});

Discourse.View.registerHelper('activityFilter', Discourse.ActivityFilterView);
