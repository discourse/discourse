import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import KeyValueStore from "discourse/lib/key-value-store";
import {
  context,
  confirmNotification
} from "discourse/lib/desktop-notifications";
import {
  subscribe as subscribePushNotification,
  unsubscribe as unsubscribePushNotification,
  isPushNotificationsSupported,
  keyValueStore as pushNotificationKeyValueStore,
  userSubscriptionKey as pushNotificationUserSubscriptionKey
} from "discourse/lib/push-notifications";

const keyValueStore = new KeyValueStore(context);

export default Component.extend({
  classNames: ["controls"],

  @computed("isNotSupported")
  notificationsPermission(isNotSupported) {
    return isNotSupported ? "" : Notification.permission;
  },

  @computed
  notificationsDisabled: {
    set(value) {
      keyValueStore.setItem("notifications-disabled", value);
      return keyValueStore.getItem("notifications-disabled");
    },
    get() {
      return keyValueStore.getItem("notifications-disabled");
    }
  },

  @computed
  isNotSupported() {
    return typeof window.Notification === "undefined";
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
  isEnabledDesktop(isGrantedPermission, notificationsDisabled) {
    return isGrantedPermission ? !notificationsDisabled : false;
  },

  @computed
  isEnabledPush: {
    set(value) {
      const user = this.currentUser;
      if (!user) {
        return false;
      }
      pushNotificationKeyValueStore.setItem(
        pushNotificationUserSubscriptionKey(user),
        value
      );
      return pushNotificationKeyValueStore.getItem(
        pushNotificationUserSubscriptionKey(user)
      );
    },
    get() {
      const user = this.currentUser;
      return user
        ? pushNotificationKeyValueStore.getItem(
            pushNotificationUserSubscriptionKey(user)
          )
        : false;
    }
  },

  isEnabled: Ember.computed.or("isEnabledDesktop", "isEnabledPush"),

  isPushNotificationsPreferred() {
    if (!this.site.mobileView) {
      return false;
    }
    return isPushNotificationsSupported(this.site.mobileView);
  },

  actions: {
    recheckPermission() {
      this.notifyPropertyChange("notificationsPermission");
    },

    turnoff() {
      if (this.isEnabledDesktop) {
        this.set("notificationsDisabled", "disabled");
        this.notifyPropertyChange("notificationsPermission");
      }
      if (this.isEnabledPush) {
        unsubscribePushNotification(this.currentUser, () => {
          this.set("isEnabledPush", "");
        });
      }
    },

    turnon() {
      if (this.isPushNotificationsPreferred()) {
        subscribePushNotification(() => {
          this.set("isEnabledPush", "subscribed");
        }, this.siteSettings.vapid_public_key_bytes);
      } else {
        this.set("notificationsDisabled", "");
        Notification.requestPermission(() => {
          confirmNotification();
          this.notifyPropertyChange("notificationsPermission");
        });
      }
    }
  }
});
