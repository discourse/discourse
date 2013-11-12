/**
  This view is used for rendering a basic list of topics.

  @class BasicTopicListView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscourseBasicTopicListComponent = Ember.Component.extend({

  loaded: function() {
    var topicList = this.get('topicList');
    if (topicList) {
      return topicList.get('loaded');
    } else {
      return true;
    }
  }.property('topicList.loaded'),

  init: function() {
    this._super();

    var topicList = this.get('topicList');
    if (topicList) {
      this.setProperties({
        topics: topicList.get('topics'),
        sortOrder: topicList.get('sortOrder')
      });
    } else {
      // Without a topic list, we assume it's loaded always.
      this.set('loaded', true);
    }
  }

});
