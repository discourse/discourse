export default Ember.ObjectController.extend({
  needs: ['topic'],
  progressPosition: null,
  expanded: false,

  actions: {
    toggleExpansion: function(opts) {
      this.toggleProperty('expanded');
      if (this.get('expanded')) {
        this.set('toPostIndex', this.get('progressPosition'));
        if(opts && opts.highlight){
          // TODO: somehow move to view?
          Em.run.next(function(){
            $('.jump-form input').select().focus();
          });
        }
      }
    },

    jumpPost: function() {
      var postIndex = parseInt(this.get('toPostIndex'), 10);

      // Validate the post index first
      if (isNaN(postIndex) || postIndex < 1) {
        postIndex = 1;
      }
      if (postIndex > this.get('postStream.filteredPostsCount')) {
        postIndex = this.get('postStream.filteredPostsCount');
      }
      this.set('toPostIndex', postIndex);
      var stream = this.get('postStream'),
          idStream = stream.get('stream'),
          postId = idStream[postIndex - 1];

      if (!postId) {
        Em.Logger.warn("jump-post code broken - requested an index outside the stream array");
        return;
      }

      var post = stream.findLoadedPost(postId);
      if (post) {
        this.jumpTo(this.get('model').urlForPostNumber(post.get('post_number')));
      } else {
        var self = this;
        // need to load it
        stream.findPostsByIds([postId]).then(function(arr) {
          post = arr[0];
          self.jumpTo(self.get('model').urlForPostNumber(post.get('post_number')));
        });
      }
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
