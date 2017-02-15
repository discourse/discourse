export default Ember.Object.extend({
  postCountsPresent: Ember.computed.or('topic.unread', 'topic.displayNewPosts'),
  showBadges: Ember.computed.and('postBadgesEnabled', 'postCountsPresent')
});
