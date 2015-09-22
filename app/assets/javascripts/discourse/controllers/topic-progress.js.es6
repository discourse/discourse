import DiscourseURL from 'discourse/lib/url';

export default Ember.Controller.extend({
  needs: ['topic'],
  progressPosition: null,
  expanded: false,
  toPostIndex: null,

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
      if (postIndex > this.get('model.postStream.filteredPostsCount')) {
        postIndex = this.get('model.postStream.filteredPostsCount');
      }
      this.set('toPostIndex', postIndex);
      var stream = this.get('model.postStream'),
          postId = stream.findPostIdForPostNumber(postIndex);

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
      this.jumpTo(this.get('model.firstPostUrl'));
    },

    jumpBottom: function() {
      this.jumpTo(this.get('model.lastPostUrl'));
    }
  },

  // Route and close the expansion
  jumpTo: function(url) {
    this.set('expanded', false);
    DiscourseURL.routeTo(url);
  },

  streamPercentage: function() {
    if (!this.get('model.postStream.loaded')) { return 0; }
    if (this.get('model.postStream.highest_post_number') === 0) { return 0; }
    var perc = this.get('progressPosition') / this.get('model.postStream.filteredPostsCount');
    return (perc > 1.0) ? 1.0 : perc;
  }.property('model.postStream.loaded', 'progressPosition', 'model.postStream.filteredPostsCount'),

  jumpTopDisabled: function() {
    return this.get('progressPosition') <= 3;
  }.property('progressPosition'),

  filteredPostCountChanged: function(){
    if(this.get('model.postStream.filteredPostsCount') < this.get('progressPosition')){
      this.set('progressPosition', this.get('model.postStream.filteredPostsCount'));
    }
  }.observes('model.postStream.filteredPostsCount'),

  jumpBottomDisabled: function() {
    return this.get('progressPosition') >= this.get('model.postStream.filteredPostsCount') ||
           this.get('progressPosition') >= this.get('model.highest_post_number');
  }.property('model.postStream.filteredPostsCount', 'model.highest_post_number', 'progressPosition'),

  hideProgress: function() {
    if (!this.get('model.postStream.loaded')) return true;
    if (!this.get('model.currentPost')) return true;
    if (this.get('model.postStream.filteredPostsCount') < 2) return true;
    return false;
  }.property('model.postStream.loaded', 'model.currentPost', 'model.postStream.filteredPostsCount'),

  hugeNumberOfPosts: function() {
    return (this.get('model.postStream.filteredPostsCount') >= Discourse.SiteSettings.short_progress_text_threshold);
  }.property('model.highest_post_number'),

  jumpToBottomTitle: function() {
    if (this.get('hugeNumberOfPosts')) {
      return I18n.t('topic.progress.jump_bottom_with_number', {post_number: this.get('model.highest_post_number')});
    } else {
      return I18n.t('topic.progress.jump_bottom');
    }
  }.property('hugeNumberOfPosts', 'model.highest_post_number')

});
