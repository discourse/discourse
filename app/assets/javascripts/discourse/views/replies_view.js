(function() {

  window.Discourse.RepliesView = Ember.CollectionView.extend({
    templateName: 'replies',
    tagName: 'section',
    classNames: ['replies-list', 'embedded-posts', 'bottom'],
    itemViewClass: Discourse.EmbeddedPostView,
    repliesShown: (function() {
      var $this;
      $this = this.$();
      if (this.get('parentView.repliesShown')) {
        return Em.run.next(function() {
          return $this.slideDown();
        });
      } else {
        return Em.run.next(function() {
          return $this.slideUp();
        });
      }
    }).observes('parentView.repliesShown')
  });

}).call(this);
