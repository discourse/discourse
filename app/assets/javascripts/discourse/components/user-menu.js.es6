import { url } from 'discourse/lib/computed';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ['user-menu'],
  notifications: null,
  loadingNotifications: false,
  myNotificationsUrl: url('/my/notifications'),

  @observes('visible')
  _loadNotifications(visible) {
    if (visible) {
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

    // TODO: It's a bit odd to use the store in a component, but this one really
    // wants to reach out and grab notifications
    const store = this.container.lookup('store:main');
    const stale = store.findStale('notification', {recent: true});

    if (stale.hasResults) {
      this.set('notifications', stale.results);
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
