import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend({
  needs: ['topic', 'application'],
  visible: false,
  user: null,
  username: null,
  participant: null,
  avatar: null,

  postStream: Em.computed.alias('controllers.topic.postStream'),
  enoughPostsForFiltering: Em.computed.gte('participant.post_count', 2),
  viewingTopic: Em.computed.match('controllers.application.currentPath', /^topic\./),
  showFilter: Em.computed.and('viewingTopic', 'postStream.hasNoFilters', 'enoughPostsForFiltering'),

  // showFilter: Em.computed.and('postStream.hasNoFilters', 'enoughPostsForFiltering'),
  showName: Discourse.computed.propertyNotEqual('user.name', 'user.username'),

  hasUserFilters: Em.computed.gt('postStream.userFilters.length', 0),

  isSuspended: Em.computed.notEmpty('user.suspend_reason'),

  showBadges: Discourse.computed.setting('enable_badges'),

  moreBadgesCount: function() {
    return this.get('user.badge_count') - this.get('user.featured_user_badges.length');
  }.property('user.badge_count', 'user.featured_user_badges.@each'),

  showMoreBadges: Em.computed.gt('moreBadgesCount', 0),

  show: function(username, uploadedAvatarId) {
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

    if (uploadedAvatarId) {
      this.set('avatar', {username: username, uploaded_avatar_id: uploadedAvatarId});
    } else {
      this.set('avatar', null);
    }

    this.setProperties({visible: true, username: username});

    // If we click the avatar again, close it.
    if (username === currentUsername && wasVisible) {
      this.setProperties({ visible: false, username: null, avatar: null });
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
    Discourse.User.findByUsername(username).then(function (user) {
      self.set('user', user);
      self.set('avatar', user);
    });
  },

  close: function() {
    this.set('visible', false);
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
