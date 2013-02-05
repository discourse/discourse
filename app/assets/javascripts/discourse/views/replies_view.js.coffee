window.Discourse.RepliesView = Ember.CollectionView.extend
  templateName: 'replies'
  tagName: 'section'
  classNames: ['replies-list', 'embedded-posts', 'bottom'] 
  itemViewClass: Discourse.EmbeddedPostView

  repliesShown: (->
    $this = @.$()
    if @get('parentView.repliesShown')
      Em.run.next -> $this.slideDown()
    else
      Em.run.next -> $this.slideUp()
  ).observes('parentView.repliesShown')
