import DiscourseURL from 'discourse/lib/url';
import { propertyNotEqual, setting } from 'discourse/lib/computed';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
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

  postStream: Em.computed.alias('controllers.topic.model.postStream'),
  enoughPostsForFiltering: Em.computed.gte('topicPostCount', 2),
  viewingTopic: Em.computed.match('controllers.application.currentPath', /^topic\./),
  viewingAdmin: Em.computed.match('controllers.application.currentPath', /^admin\./),
  showFilter: Em.computed.and('viewingTopic', 'postStream.hasNoFilters', 'enoughPostsForFiltering'),
  showName: propertyNotEqual('user.name', 'user.username'),
  hasUserFilters: Em.computed.gt('postStream.userFilters.length', 0),
  isSuspended: Em.computed.notEmpty('user.suspend_reason'),
  showBadges: setting('enable_badges'),
  showMoreBadges: Em.computed.gt('moreBadgesCount', 0),
  showDelete: Em.computed.and("viewingAdmin", "showName", "user.canBeDeleted"),
  linkWebsite: Em.computed.not('user.isBasic'),
  hasLocationOrWebsite: Em.computed.or('user.location', 'user.website_name'),

  @computed('user.user_fields.@each.value')
  publicUserFields() {
    const siteUserFields = this.site.get('user_fields');
    if (!Ember.isEmpty(siteUserFields)) {
      const userFields = this.get('user.user_fields');
      return siteUserFields.filterProperty('show_on_user_card', true).sortBy('position').map(field => {
        Ember.set(field, 'dasherized_name', field.get('name').dasherize());
        const value = userFields ? userFields[field.get('id')] : null;
        return Ember.isEmpty(value) ? null : Ember.Object.create({ value, field });
      }).compact();
    }
  },

  @computed("user.trust_level")
  removeNoFollow(trustLevel) {
    return trustLevel > 2 && !this.siteSettings.tl3_links_no_follow;
  },

  moreBadgesCount: function() {
    return this.get('user.badge_count') - this.get('user.featured_user_badges.length');
  }.property('user.badge_count', 'user.featured_user_badges.[]'),

  hasCardBadgeImage: function() {
    const img = this.get('user.card_badge.image');
    return img && img.indexOf('fa-') !== 0;
  }.property('user.card_badge.image'),

  show(username, postId, target) {
    // XSS protection (should be encapsulated)
    username = username.toString().replace(/[^A-Za-z0-9_\.\-]/g, "");

    // No user card for anon
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      return;
    }

    // Don't show on mobile
    if (this.site.mobileView) {
      const url = "/users/" + username;
      DiscourseURL.routeTo(url);
      return;
    }

    const currentUsername = this.get('username'),
      wasVisible = this.get('visible'),
      previousTarget = this.get('cardTarget'),
      post = this.get('viewingTopic') && postId ? this.get('postStream').findLoadedPost(postId) : null;

    if (username === currentUsername && this.get('userLoading') === username) {
      // debounce
      return;
    }

    if (wasVisible) {
      this.close();
      if (target === previousTarget) {
        return;  // Same target, close it without loading the new user card
      }
    }

    this.setProperties({ username, userLoading: username, cardTarget: target, post });

    const args = { stats: false };
    args.include_post_count_for = this.get('controllers.topic.model.id');
    args.skip_track_visit = true;

    return Discourse.User.findByUsername(username, args).then((user) => {
      if (user.topic_post_count) {
        this.set('topicPostCount', user.topic_post_count[args.include_post_count_for]);
      }
      this.setProperties({ user, avatar: user, visible: true });
    }).catch((error) => {
      this.close();
      throw error;
    }).finally(() => {
      this.set('userLoading', null);
    });
  },

  close() {
    this.setProperties({
      visible: false,
      user: null,
      username: null,
      avatar: null,
      userLoading: null,
      cardTarget: null,
      post: null,
      topicPostCount: null
    });
  },

  actions: {
    togglePosts(user) {
      const postStream = this.get('postStream');
      postStream.toggleParticipant(user.get('username'));
      this.close();
    },

    cancelFilter() {
      const postStream = this.get('postStream');
      postStream.cancelFilter();
      postStream.refresh();
      this.close();
    },

    showUser() {
      this.transitionToRoute('user', this.get('user'));
      this.close();
    }
  }

});
