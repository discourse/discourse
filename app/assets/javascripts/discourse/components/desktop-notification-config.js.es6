import computed from 'ember-addons/ember-computed-decorators';
import KeyValueStore from 'discourse/lib/key-value-store';

const keyValueStore = new KeyValueStore("discourse_desktop_notifications_");

import {
  subscribe as subscribePushNotification,
  unsubscribe as unsubscribePushNotification,
  isPushNotificationsSupported
} from 'discourse/lib/push-notifications';

export default Ember.Component.extend({
  classNames: ['controls'],

  @computed("isNotSupported")
  notificationsPermission(isNotSupported) {
    return isNotSupported ? "" : Notification.permission;
  },

  @computed
  notificationsDisabled: {
    set(value) {
      keyValueStore.setItem('notifications-disabled', value);
      return keyValueStore.getItem('notifications-disabled');
    },
    get() {
      return keyValueStore.getItem('notifications-disabled');
    }
  },

  @computed
  isNotSupported() {
    return typeof window.Notification === "undefined";
  },

  @computed("isNotSupported", "notificationsPermission")
  isDefaultPermission(isNotSupported, notificationsPermission) {
    return isNotSupported ? false : notificationsPermission === "default";
  },

  @computed('isEnabled')
  showPushNotification(isEnabled) {
    return isEnabled && isPushNotificationsSupported();
  },

  @computed
  pushNotficationSubscribed: {
    set(value) {
      localStorage.setItem('push-notification-subscribed', value);
      return localStorage.getItem('push-notification-subscribed');
    },
    get() {
      return localStorage.getItem('push-notification-subscribed');
    }
  },

  isDeniedPermission: function() {
    if (this.get('isNotSupported')) return false;

    return Notification.permission === "denied";
  }.property('isNotSupported', 'notificationsPermission'),

  isGrantedPermission: function() {
    if (this.get('isNotSupported')) return false;
  },

  @computed("isNotSupported", "notificationsPermission")
  isDeniedPermission(isNotSupported, notificationsPermission) {
    return isNotSupported ? false : notificationsPermission === "denied";
  },

  @computed("isNotSupported", "notificationsPermission")
  isGrantedPermission(isNotSupported, notificationsPermission) {
    return isNotSupported ? false : notificationsPermission === "granted";
  },

  @computed("isGrantedPermission", "notificationsDisabled")
  isEnabled(isGrantedPermission, notificationsDisabled) {
    return isGrantedPermission ? !notificationsDisabled : false;
  },

  actions: {
    requestPermission() {
      Notification.requestPermission(() => this.propertyDidChange('notificationsPermission'));
    },

    recheckPermission() {
      this.propertyDidChange('notificationsPermission');
    },

    turnoff() {
      this.set('notificationsDisabled', 'disabled');
      this.propertyDidChange('notificationsPermission');
      this.send('unsubscribe');
    },

    turnon() {
      this.set('notificationsDisabled', '');
      this.propertyDidChange('notificationsPermission');
    },
    subscribe() {
      const self = this;

      subscribePushNotification(() => {
        self.set("pushNotficationSubscribed", 'subscribed');
      });
    },
    unsubscribe() {
      const self = this;

      unsubscribePushNotification(() => {
        self.set("pushNotficationSubscribed", '');
      });
    }
  }
});
