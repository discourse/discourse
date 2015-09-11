export default Ember.Object.extend({
  postCountsPresent: Ember.computed.or('topic.unread', 'topic.displayNewPosts', 'topic.unseen'),
  showBadges: Ember.computed.and('postBadgesEnabled', 'postCountsPresent')
});
