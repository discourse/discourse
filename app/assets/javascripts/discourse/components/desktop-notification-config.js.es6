import computed from 'ember-addons/ember-computed-decorators';
import KeyValueStore from 'discourse/lib/key-value-store';

const keyValueStore = new KeyValueStore("discourse_desktop_notifications_");

import {
  subscribe as subscribePushNotification,
  unsubscribe as unsubscribePushNotification,
  isPushNotificationsSupported,
  keyValueStore as pushNotificationKeyValueStore,
  userSubscriptionKey as pushNotificationUserSubscriptionKey
} from 'discourse/lib/push-notifications';

import {
  subscribe as subscribeToNotificationAlert,
  unsubscribe as unsubscribeToNotificationAlert
} from 'discourse/lib/desktop-notifications';

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
      const user = Discourse.User.current();
      pushNotificationKeyValueStore.setItem(pushNotificationUserSubscriptionKey(user), value);
      return pushNotificationKeyValueStore.getItem(pushNotificationUserSubscriptionKey(user));
    },
    get() {
      return pushNotificationKeyValueStore.getItem(pushNotificationUserSubscriptionKey(Discourse.User.current()));
    }
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
        unsubscribeToNotificationAlert(self.messageBus, Discourse.User.current());
        self.set("pushNotficationSubscribed", 'subscribed');
      });
    },
    unsubscribe() {
      const self = this;

      unsubscribePushNotification(() => {
        subscribeToNotificationAlert(self.messageBus, Discourse.User.current());
        self.set("pushNotficationSubscribed", '');
      });
    }
  }
});
