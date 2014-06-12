export default Ember.ObjectController.extend({
  needs: ['topic'],
  progressPosition: null,

  streamPercentage: function() {
    if (!this.get('postStream.loaded')) { return 0; }
    if (this.get('postStream.highest_post_number') === 0) { return 0; }
    var perc = this.get('progressPosition') / this.get('postStream.filteredPostsCount');
    return (perc > 1.0) ? 1.0 : perc;
  }.property('postStream.loaded', 'progressPosition', 'postStream.filteredPostsCount'),

  jumpTopDisabled: function() {
    return (this.get('progressPosition') < 2);
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
