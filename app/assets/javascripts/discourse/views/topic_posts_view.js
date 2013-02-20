(function() {

  window.Discourse.TopicPostsView = Em.CollectionView.extend({
    itemViewClass: Discourse.PostView,
    didInsertElement: function() {
      return this.get('topicView').postsRendered();
    }
  });

}).call(this);
