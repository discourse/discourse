import { default as computed } from 'ember-addons/ember-computed-decorators';
import { propertyNotEqual, setting } from 'discourse/lib/computed';
import { durationTiny } from 'discourse/lib/formatter';
import CanCheckEmails from 'discourse/mixins/can-check-emails';

export default Ember.Component.extend(CanCheckEmails, {

  allowBackgrounds: setting('allow_profile_backgrounds'),
  showBadges: setting('enable_badges'),

  enoughPostsForFiltering: Ember.computed.gte('topicPostCount', 2),
  showFilter: Ember.computed.and('viewingTopic', 'postStream.hasNoFilters', 'enoughPostsForFiltering'),
  showName: propertyNotEqual('user.name', 'user.username'),
  hasUserFilters: Ember.computed.gt('postStream.userFilters.length', 0),
  isSuspended: Ember.computed.notEmpty('user.suspend_reason'),
  showMoreBadges: Ember.computed.gt('moreBadgesCount', 0),
  showDelete: Ember.computed.and("viewingAdmin", "showName", "user.canBeDeleted"),
  linkWebsite: Ember.computed.not('user.isBasic'),
  hasLocationOrWebsite: Ember.computed.or('user.location', 'user.website_name'),
  showCheckEmail: Ember.computed.and('user.staged', 'canCheckEmails'),

  @computed('user.name')
  nameFirst(name) {
    return !this.siteSettings.prioritize_username_in_ux && name && name.trim().length > 0;
  },

  @computed('username', 'topicPostCount')
  togglePostsLabel(username, count) {
    return I18n.t("topic.filter_to", { username, count });
  },

  @computed('user.user_fields.@each.value')
  publicUserFields() {
    const siteUserFields = this.site.get('user_fields');
    if (!Ember.isEmpty(siteUserFields)) {
      const userFields = this.get('user.user_fields');
      return siteUserFields.filterBy('show_on_user_card', true).sortBy('position').map(field => {
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

  @computed('user.badge_count', 'user.featured_user_badges.length')
  moreBadgesCount: (badgeCount, badgeLength) => badgeCount - badgeLength,

  @computed('user.time_read', 'user.recent_time_read')
  showRecentTimeRead(timeRead, recentTimeRead) {
    return timeRead !== recentTimeRead && recentTimeRead !== 0;
  },

  @computed('user.recent_time_read')
  recentTimeRead(recentTimeReadSeconds) {
    return durationTiny(recentTimeReadSeconds);
  },

  @computed('showRecentTimeRead', 'user.time_read', 'recentTimeRead')
  timeReadTooltip(showRecent, timeRead, recentTimeRead) {
    if (showRecent) {
      return I18n.t('time_read_recently_tooltip', {time_read: durationTiny(timeRead), recent_time_read: recentTimeRead});
    } else {
      return I18n.t('time_read_tooltip', {time_read: durationTiny(timeRead)});
    }
  },

  actions: {
    close() {
      this.sendAction('close');
    },

    cancelFilter() {
      this.sendAction('cancelFilter');
    },

    composePrivateMessage(...args) {
      this.sendAction('composePrivateMessage', ...args);
    },

    togglePosts() {
      this.sendAction('togglePosts');
    },

    deleteUser() {
      this.sendAction('deleteUser');
    },

    showUser() {
      this.sendAction('showUser');
    },

    checkEmail(user) {
      this.sendAction('showUser', user);
    }
  }
});
