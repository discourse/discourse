/**
  This view handles the rendering of a topic in a list

  @class TopicListItemView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicListItemView = Discourse.View.extend({
  tagName: 'tr',
  templateName: 'list/topic_list_item',
  classNameBindings: ['content.archived', ':topic-list-item', 'content.hasExcerpt:has-excerpt'],
  attributeBindings: ['data-topic-id'],

  'data-topic-id': (function() {
    return this.get('content.id');
  }).property('content.id'),

  init: function() {
    this._super();
    return this.set('context', this.get('content'));
  },

  highlight: function() {
    var $topic, originalCol;
    $topic = this.$();
    originalCol = $topic.css('backgroundColor');
    return $topic.css({
      backgroundColor: "#ffffcc"
    }).animate({
      backgroundColor: originalCol
    }, 2500);
  },

  didInsertElement: function() {
    // highligth the last topic viewed
    if (Discourse.get('transient.lastTopicIdViewed') === this.get('content.id')) {
      Discourse.set('transient.lastTopicIdViewed', null);
      this.highlight();
    }
    // highlight new topics that have been loaded from the server or the one we just created
    else if (this.get('content.highlight')) {
      this.set('content.highlight', false);
      this.highlight();
    }
  }

});
