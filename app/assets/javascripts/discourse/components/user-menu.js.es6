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

  loadCachedNotifications() {
    var notifications;
    try {
      notifications = JSON.parse(localStorage["notifications"]);
      notifications = notifications.map(n => Em.Object.create(n));
    } catch (e) {
      notifications = null;
    }
    return notifications;
  },

  // TODO push this kind of functionality into Rest thingy
  cacheNotifications(notifications) {
    const keys = ["id", "notification_type", "read", "created_at", "post_number", "topic_id", "slug", "data"];
    const serialized = JSON.stringify(notifications.map(n => n.getProperties(keys)));
    const changed = serialized !== localStorage["notifications"];
    localStorage["notifications"] = serialized;
    return changed;
  },

  refreshNotifications() {

    if (this.get('loadingNotifications')) { return; }

    var cached = this.loadCachedNotifications();

    if (cached) {
      this.set("notifications", cached);
    } else {
      this.set("loadingNotifications", true);
    }

    // TODO: It's a bit odd to use the store in a component, but this one really
    // wants to reach out and grab notifications
    const store = this.container.lookup('store:main');
    store.find('notification', {recent: true}).then((notifications) => {
      this.set('currentUser.unread_notifications', 0);
      if (this.cacheNotifications(notifications)) {
        this.setProperties({ notifications });
      }
    }).catch(() => {
      this.set('notifications', null);
    }).finally(() => {
      this.set("loadingNotifications", false);
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
    }
  }
});
