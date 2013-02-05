window.Discourse.TopicPostsView = Em.CollectionView.extend
  itemViewClass: Discourse.PostView

  didInsertElement: -> @get('topicView').postsRendered()
