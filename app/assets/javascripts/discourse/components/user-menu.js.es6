import { url } from 'discourse/lib/computed';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import { headerHeight } from 'discourse/views/header';

export default Ember.Component.extend({
  classNames: ['user-menu'],
  notifications: null,
  loadingNotifications: false,
  notificationsPath: url('currentUser.path', '%@/notifications'),
  bookmarksPath: url('currentUser.path', '%@/activity/bookmarks'),
  messagesPath: url('currentUser.path', '%@/messages'),
  preferencesPath: url('currentUser.path', '%@/preferences'),

  @computed('allowAnon', 'isAnon')
  showEnableAnon(allowAnon, isAnon) { return allowAnon && !isAnon; },

  @computed('allowAnon', 'isAnon')
  showDisableAnon(allowAnon, isAnon) { return allowAnon && isAnon; },

  @observes('visible')
  _loadNotifications() {
    if (this.get("visible")) {
      this.refreshNotifications();
    }
  },

  @observes('currentUser.lastNotificationChange')
  _resetCachedNotifications() {
    const visible = this.get('visible');

    if (!Discourse.get("hasFocus")) {
      this.set('visible', false);
      this.set('notifications', null);
      return;
    }

    if (visible) {
      this.refreshNotifications();
    } else {
      this.set('notifications', null);
    }
  },

  refreshNotifications() {
    if (this.get('loadingNotifications')) { return; }

    // estimate (poorly) the amount of notifications to return
    var limit = Math.round(($(window).height() - headerHeight()) / 55);
    // we REALLY don't want to be asking for negative counts of notifications
    // less than 5 is also not that useful
    if (limit < 5) { limit = 5; }
    if (limit > 40) { limit = 40; }

    // TODO: It's a bit odd to use the store in a component, but this one really
    // wants to reach out and grab notifications
    const store = this.container.lookup('store:main');
    const stale = store.findStale('notification', {recent: true, limit }, {storageKey: 'recent-notifications'});

    if (stale.hasResults) {
      const results = stale.results;
      var content = results.get('content');

      // we have to truncate to limit, otherwise we will render too much
      if (content && (content.length > limit)) {
        content = content.splice(0, limit);
        results.set('content', content);
        results.set('totalRows', limit);
      }

      this.set('notifications', results);
    } else {
      this.set('loadingNotifications', true);
    }

    stale.refresh().then((notifications) => {
      this.set('currentUser.unread_notifications', 0);
      this.set('notifications', notifications);
    }).catch(() => {
      this.set('notifications', null);
    }).finally(() => {
      this.set('loadingNotifications', false);
    });
  },

  @computed()
  allowAnon() {
    return this.siteSettings.allow_anonymous_posting &&
      (this.get("currentUser.trust_level") >= this.siteSettings.anonymous_posting_min_trust_level ||
       this.get("isAnon"));
  },

  isAnon: Ember.computed.alias('currentUser.is_anonymous'),

  actions: {
    toggleAnon() {
      Discourse.ajax("/users/toggle-anon", {method: 'POST'}).then(function(){
        window.location.reload();
      });
    },
    logout() {
      this.sendAction('logoutAction');
    }
  }
});
