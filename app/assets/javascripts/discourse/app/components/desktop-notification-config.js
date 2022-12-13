import {
  confirmNotification,
  context,
} from "discourse/lib/desktop-notifications";
import {
  isPushNotificationsSupported,
  keyValueStore as pushNotificationKeyValueStore,
  userSubscriptionKey as pushNotificationUserSubscriptionKey,
  subscribe as subscribePushNotification,
  unsubscribe as unsubscribePushNotification,
} from "discourse/lib/push-notifications";
import Component from "@ember/component";
import KeyValueStore from "discourse/lib/key-value-store";
import discourseComputed from "discourse-common/utils/decorators";
import { or } from "@ember/object/computed";

const keyValueStore = new KeyValueStore(context);

export default Component.extend({
  classNames: ["controls"],

  @discourseComputed("isNotSupported")
  notificationsPermission(isNotSupported) {
    return isNotSupported ? "" : Notification.permission;
  },

  @discourseComputed
  notificationsDisabled: {
    set(value) {
      keyValueStore.setItem("notifications-disabled", value);
      return keyValueStore.getItem("notifications-disabled");
    },
    get() {
      return keyValueStore.getItem("notifications-disabled");
    },
  },

  @discourseComputed
  isNotSupported() {
    return typeof window.Notification === "undefined";
  },

  @discourseComputed("isNotSupported", "notificationsPermission")
  isDeniedPermission(isNotSupported, notificationsPermission) {
    return isNotSupported ? false : notificationsPermission === "denied";
  },

  @discourseComputed("isNotSupported", "notificationsPermission")
  isGrantedPermission(isNotSupported, notificationsPermission) {
    return isNotSupported ? false : notificationsPermission === "granted";
  },

  @discourseComputed("isGrantedPermission", "notificationsDisabled")
  isEnabledDesktop(isGrantedPermission, notificationsDisabled) {
    return isGrantedPermission ? !notificationsDisabled : false;
  },

  // TODO: (selase) getter should consistently return a boolean
  @discourseComputed
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
    },
  },

  isEnabled: or("isEnabledDesktop", "isEnabledPush"),

  @discourseComputed("isEnabled", "isEnabledPush", "notificationsDisabled")
  isSubscribed(isEnabled, isEnabledPush, notificationsDisabled) {
    if (!isEnabled) {
      return false;
    }

    if (this.isPushNotificationsPreferred()) {
      return isEnabledPush === "subscribed";
    } else {
      return notificationsDisabled === "";
    }
  },

  isPushNotificationsPreferred() {
    return (
      (this.site.mobileView ||
        this.siteSettings.enable_desktop_push_notifications) &&
      isPushNotificationsSupported()
    );
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
          confirmNotification(this.siteSettings);
          this.notifyPropertyChange("notificationsPermission");
        });
      }
    },
  },
});
