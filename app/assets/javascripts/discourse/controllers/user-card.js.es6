import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend({
  needs: ['topic', 'application'],
  visible: false,
  user: null,
  username: null,
  avatar: null,
  userLoading: null,
  cardTarget: null,
  post: null,

  // If inside a topic
  topicPostCount: null,

  postStream: Em.computed.alias('controllers.topic.postStream'),
  enoughPostsForFiltering: Em.computed.gte('topicPostCount', 2),
  viewingTopic: Em.computed.match('controllers.application.currentPath', /^topic\./),
  viewingAdmin: Em.computed.match('controllers.application.currentPath', /^admin\./),
  showFilter: Em.computed.and('viewingTopic', 'postStream.hasNoFilters', 'enoughPostsForFiltering'),
  showName: Discourse.computed.propertyNotEqual('user.name', 'user.username'),
  hasUserFilters: Em.computed.gt('postStream.userFilters.length', 0),
  isSuspended: Em.computed.notEmpty('user.suspend_reason'),
  showBadges: Discourse.computed.setting('enable_badges'),
  showMoreBadges: Em.computed.gt('moreBadgesCount', 0),
  showDelete: Em.computed.and("viewingAdmin", "showName", "user.canBeDeleted"),

  moreBadgesCount: function() {
    return this.get('user.badge_count') - this.get('user.featured_user_badges.length');
  }.property('user.badge_count', 'user.featured_user_badges.@each'),

  hasCardBadgeImage: function() {
    const img = this.get('user.card_badge.image');
    return img && img.indexOf('fa-') !== 0;
  }.property('user.card_badge.image'),

  show(username, postId, target) {
    // XSS protection (should be encapsulated)
    username = username.toString().replace(/[^A-Za-z0-9_]/g, "");
    const url = "/users/" + username;

    // Don't show on mobile
    if (Discourse.Mobile.mobileView) {
      Discourse.URL.routeTo(url);
      return;
    }

    const currentUsername = this.get('username'),
        wasVisible = this.get('visible'),
        post = this.get('viewingTopic') && postId ? this.get('controllers.topic.postStream').findLoadedPost(postId) : null;

    this.setProperties({ avatar: null, post: post, username: username });

    // If we click the avatar again, close it (unless its diff element on the screen).
    if (target === this.get('cardTarget') && wasVisible) {
      this.setProperties({ visible: false, username: null, cardTarget: null });
      return;
    }

    if (username === currentUsername && this.get('userLoading') === username) {
      // debounce
      return;
    }

    this.set('topicPostCount', null);

    this.setProperties({ user: null, userLoading: username, cardTarget: target });

    const args = { stats: false };
    args.include_post_count_for = this.get('controllers.topic.id');

    const self = this;
    return Discourse.User.findByUsername(username, args).then(function(user) {

      if (user.topic_post_count) {
        self.set('topicPostCount', user.topic_post_count[args.include_post_count_for]);
      }
      user = Discourse.User.create(user);
      self.setProperties({ user, avatar: user, visible: true});
      self.appEvents.trigger('usercard:shown');
    }).catch(function(error) {
      self.close();
      throw error;
    }).finally(function() {
      self.set('userLoading', null);
    });
  },

  close() {
    this.setProperties({ visible: false, cardTarget: null });
  },

  actions: {
    togglePosts(user) {
      const postStream = this.get('controllers.topic.postStream');
      postStream.toggleParticipant(user.get('username'));
      this.close();
    },

    cancelFilter() {
      const postStream = this.get('postStream');
      postStream.cancelFilter();
      postStream.refresh();
      this.close();
    }
  }

});
