import StringBuffer from 'discourse/mixins/string-buffer';

export default Discourse.View.extend(StringBuffer, {
  rerenderTriggers: ['controller.bulkSelectEnabled', 'topic.pinned'],
  tagName: 'tr',
  rawTemplate: 'list/topic_list_item.raw',
  classNameBindings: ['controller.checked', 'content.archived', ':topic-list-item', 'content.hasExcerpt:has-excerpt'],
  attributeBindings: ['data-topic-id'],
  'data-topic-id': Em.computed.alias('content.id'),
  titleColSpan: function(){
    return (!this.get('controller.hideCategory') &&
             this.get('content.isPinnedUncategorized') ? 2 : 1);
  }.property(),

  topic: Em.computed.alias("content"),

  click: function(e){
    var target = $(e.target);

    if(target.hasClass('posts-map')){
      if(target.prop('tagName') !== 'A'){
        target = target.find('a');
      }
      this.container.lookup('controller:application').send("showTopicEntrance", {topic: this.get('content'), position: target.offset()});
      return false;
    }

    if(target.hasClass('bulk-select')){
      var selected = this.get('controller.selected');
      var topic = this.get('content');

      if(target.is(':checked')){
        selected.addObject(topic);
      } else {
        selected.removeObject(topic);
      }
    }

    if(target.closest('a.topic-status').length === 1){
      this.get('topic').togglePinnedForUser();
      return false;
    }
  },

  highlight: function() {
    var $topic = this.$();
    var originalCol = $topic.css('backgroundColor');
    $topic
      .addClass('highlighted')
      .stop()
      .animate({ backgroundColor: originalCol }, 2500, 'swing', function(){
        $topic.removeClass('highlighted');
      });
  },

  _highlightIfNeeded: function() {
    // highlight the last topic viewed
    if (this.session.get('lastTopicIdViewed') === this.get('content.id')) {
      this.session.set('lastTopicIdViewed', null);
      this.highlight();
    } else if (this.get('content.highlight')) {
      // highlight new topics that have been loaded from the server or the one we just created
      this.set('content.highlight', false);
      this.highlight();
    }
  }.on('didInsertElement')

});
