/**
  This view is used for rendering a basic list of topics.

  @class BasicTopicListComponent
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
export default Ember.Component.extend({

  loaded: function() {
    var topicList = this.get('topicList');
    if (topicList) {
      return topicList.get('loaded');
    } else {
      return true;
    }
  }.property('topicList.loaded'),

  _topicListChanged: function() {
    this._initFromTopicList(this.get('topicList'));
  }.observes('topicList.@each'),

  _initFromTopicList: function(topicList) {
    if (topicList !== null) {
      this.set('topics', topicList.get('topics'));
      this.rerender();
    }
  },

  init: function() {
    this._super();
    var topicList = this.get('topicList');
    if (topicList) {
      this._initFromTopicList(topicList);
    } else {
      // Without a topic list, we assume it's loaded always.
      this.set('loaded', true);
    }
  }

});
