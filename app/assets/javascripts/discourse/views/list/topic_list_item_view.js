(function() {

  window.Discourse.TopicListItemView = Ember.View.extend({
    tagName: 'tr',
    templateName: 'list/topic_list_item',
    classNameBindings: ['content.archived', ':topic-list-item'],
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
      if (Discourse.get('transient.lastTopicIdViewed') === this.get('content.id')) {
        Discourse.set('transient.lastTopicIdViewed', null);
        this.highlight();
        return;
      }
      if (this.get('content.highlightAfterInsert')) {
        return this.highlight();
      }
    }
  });

}).call(this);
