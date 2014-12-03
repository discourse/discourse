import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend({
  needs: ['topic', 'application'],
  visible: false,
  user: null,
  username: null,
  participant: null,
  avatar: null,
  userLoading: null,
  cardTarget: null,

  postStream: Em.computed.alias('controllers.topic.postStream'),
  enoughPostsForFiltering: Em.computed.gte('participant.post_count', 2),
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
    var img = this.get('user.card_badge.image');
    return img && img.indexOf('fa-') !== 0;
  }.property('user.card_badge.image'),

  show: function(username, target) {
    // XSS protection (should be encapsulated)
    username = username.replace(/[^A-Za-z0-9_]/g, "");
    var url = "/users/" + username;

    // Don't show on mobile
    if (Discourse.Mobile.mobileView) {
      Discourse.URL.routeTo(url);
      return;
    }

    var currentUsername = this.get('username'),
        wasVisible = this.get('visible');

    this.set('avatar', null);
    this.set('username', username);

    // If we click the avatar again, close it (unless its diff element on the screen).
    if (target === this.get('cardTarget') && wasVisible) {
      this.setProperties({ visible: false, username: null, avatar: null, cardTarget: null });
      return;
    }

    if (username === currentUsername && this.get('userLoading') === username) {
      // debounce
      return;
    }

    this.set('participant', null);

    // Retrieve their participants info
    var participants = this.get('controllers.topic.details.participants');
    if (participants) {
      this.set('participant', participants.findBy('username', username));
    }

    var self = this;
    self.set('user', null);
    self.set('userLoading', username);
    self.set('cardTarget', target);

    Discourse.User.findByUsername(username).then(function (user) {
      user = Discourse.User.create(user);
      self.setProperties({ user: user, avatar: user, visible: true});
      self.appEvents.trigger('usercard:shown');
    }).finally(function(){
      self.set('userLoading', null);
    });
  },

  close: function() {
    this.set('visible', false);
    this.set('cardTarget', null);
  },

  actions: {
    togglePosts: function(user) {
      var postStream = this.get('controllers.topic.postStream');
      postStream.toggleParticipant(user.get('username'));
      this.close();
    },

    cancelFilter: function() {
      var postStream = this.get('postStream');
      postStream.cancelFilter();
      postStream.refresh();
      this.close();
    }
  }

});
