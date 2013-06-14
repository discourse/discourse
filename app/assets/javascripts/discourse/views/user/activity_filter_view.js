/**
  This view handles rendering of an activity in a user's stream

  @class ActivityFilterView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ActivityFilterView = Discourse.View.extend({
  tagName: 'li',
  classNameBindings: ['active'],

  stream: Em.computed.alias('controller.content'),

  countChanged: function(){
    this.rerender();
  }.observes('count'),

  active: function() {
    var content = this.get('content');
    if (content) {
      return parseInt(this.get('stream.filter'), 10) === parseInt(Em.get(content, 'action_type'), 10);
    } else {
      return this.blank('stream.filter');
    }
  }.property('stream.filter', 'content.action_type'),

  render: function(buffer) {
    var content = this.get('content');
    var count, description;

    if (content) {
      count = Em.get(content, 'count');
      description = Em.get(content, 'description');
    } else {
      count = this.get('count');
      description = Em.String.i18n("user.filters.all");
    }

    buffer.push("<a href='#'>" + description +
        " <span class='count'>(" + count + ")</span><span class='icon-chevron-right'></span></a>");
  },

  click: function() {
    this.set('stream.filter', this.get('content.action_type'));
    return false;
  }
});

Discourse.View.registerHelper('activityFilter', Discourse.ActivityFilterView);