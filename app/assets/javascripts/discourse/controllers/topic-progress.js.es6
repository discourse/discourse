export default Ember.ObjectController.extend({
  needs: ['topic'],
  progressPosition: null,
  expanded: false,

  actions: {
    toggleExpansion: function() {
      this.toggleProperty('expanded');
      if (this.get('expanded')) {
        this.set('toPostNumber', this.get('progressPosition'));
      }
    },

    jumpPost: function() {
      var postNumber = parseInt(this.get('toPostNumber'), 10);

      // Validate the post number first
      if (isNaN(postNumber) || postNumber < 1) {
        postNumber = 1;
      }
      if (postNumber > this.get('highest_post_number')) {
        postNumber = this.get('highest_post_number');
      }
      this.set('toPostNumber', postNumber);
      this.jumpTo(this.get('model').urlForPostNumber(postNumber));
    },

    jumpTop: function() {
      this.jumpTo(this.get('firstPostUrl'));
    },

    jumpBottom: function() {
      this.jumpTo(this.get('lastPostUrl'));
    }
  },

  // Route and close the expansion
  jumpTo: function(url) {
    this.set('expanded', false);
    Discourse.URL.routeTo(url);
  },

  streamPercentage: function() {
    if (!this.get('postStream.loaded')) { return 0; }
    if (this.get('postStream.highest_post_number') === 0) { return 0; }
    var perc = this.get('progressPosition') / this.get('postStream.filteredPostsCount');
    return (perc > 1.0) ? 1.0 : perc;
  }.property('postStream.loaded', 'progressPosition', 'postStream.filteredPostsCount'),

  jumpTopDisabled: function() {
    return this.get('progressPosition') <= 3;
  }.property('progressPosition'),

  filteredPostCountChanged: function(){
    if(this.get('postStream.filteredPostsCount') < this.get('progressPosition')){
      this.set('progressPosition', this.get('postStream.filteredPostsCount'));
    }
  }.observes('postStream.filteredPostsCount'),

  jumpBottomDisabled: function() {
    return this.get('progressPosition') >= this.get('postStream.filteredPostsCount') ||
           this.get('progressPosition') >= this.get('highest_post_number');
  }.property('postStream.filteredPostsCount', 'highest_post_number', 'progressPosition'),

  hideProgress: function() {
    if (!this.get('postStream.loaded')) return true;
    if (!this.get('currentPost')) return true;
    if (this.get('postStream.filteredPostsCount') < 2) return true;
    return false;
  }.property('postStream.loaded', 'currentPost', 'postStream.filteredPostsCount'),

  hugeNumberOfPosts: function() {
    return (this.get('postStream.filteredPostsCount') >= Discourse.SiteSettings.short_progress_text_threshold);
  }.property('highest_post_number'),

  jumpToBottomTitle: function() {
    if (this.get('hugeNumberOfPosts')) {
      return I18n.t('topic.progress.jump_bottom_with_number', {post_number: this.get('highest_post_number')});
    } else {
      return I18n.t('topic.progress.jump_bottom');
    }
  }.property('hugeNumberOfPosts', 'highest_post_number')

});
