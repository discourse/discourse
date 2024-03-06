import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { inject as service } from "@ember/service";
import {
  confirmNotification,
  context,
} from "discourse/lib/desktop-notifications";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import KeyValueStore from "discourse/lib/key-value-store";
import {
  isPushNotificationsSupported,
  keyValueStore as pushNotificationKeyValueStore,
  subscribe as subscribePushNotification,
  unsubscribe as unsubscribePushNotification,
  userSubscriptionKey as pushNotificationUserSubscriptionKey,
} from "discourse/lib/push-notifications";

const keyValueStore = new KeyValueStore(context);

@disableImplicitInjections
export default class DesktopNotificationsService extends Service {
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked notificationsDisabled;
  @tracked isEnabledPush;

  constructor() {
    super(...arguments);
    this.notificationsDisabled = keyValueStore.getItem(
      "notifications-disabled"
    );
    this.isEnabledPush = this.currentUser
      ? pushNotificationKeyValueStore.getItem(
          pushNotificationUserSubscriptionKey(this.currentUser)
        )
      : false;
  }

  get isNotSupported() {
    return typeof window.Notification === "undefined";
  }

  get notificationsPermission() {
    return this.isNotSupported ? "" : Notification.permission;
  }

  setNotificationsDisabled(value) {
    keyValueStore.setItem("notifications-disabled", value);
    this.notificationsDisabled = keyValueStore.getItem(
      "notifications-disabled"
    );
  }

  get isDeniedPermission() {
    if (this.isNotSupported) {
      return false;
    }

    return this.notificationsPermission === "denied";
  }

  get isGrantedPermission() {
    if (this.isNotSupported) {
      return false;
    }

    return this.notificationsPermission === "granted";
  }

  get isEnabledDesktop() {
    if (this.isGrantedPermission) {
      return this.notificationsDisabled;
    }

    return false;
  }

  setIsEnabledPush(value) {
    const user = this.currentUser;
    if (!user) {
      return false;
    }
    pushNotificationKeyValueStore.setItem(
      pushNotificationUserSubscriptionKey(user),
      value
    );
    this.isEnabledPush = pushNotificationKeyValueStore.getItem(
      pushNotificationUserSubscriptionKey(user)
    );
  }

  get isEnabled() {
    return this.isEnabledDesktop || this.isEnabledPush;
  }

  get isSubscribed() {
    if (!this.isEnabled) {
      return false;
    }

    if (this.isPushNotificationsPreferred) {
      return this.isEnabledPush === "subscribed";
    } else {
      return this.notificationsDisabled === "";
    }
  }

  get isPushNotificationsPreferred() {
    return (
      (this.site.mobileView ||
        this.siteSettings.enable_desktop_push_notifications) &&
      isPushNotificationsSupported()
    );
  }

  @action
  disable() {
    if (this.isEnabledDesktop) {
      this.setNotificationsDisabled("disabled");
      return true;
    }
    if (this.isEnabledPush) {
      return unsubscribePushNotification(this.currentUser, () => {
        this.setIsEnabledPush("");
      });
    }
  }

  @action
  enable() {
    if (this.isPushNotificationsPreferred) {
      return subscribePushNotification(() => {
        this.setIsEnabledPush("subscribed");
      }, this.siteSettings.vapid_public_key_bytes);
    } else {
      this.setNotificationsDisabled("");
      return Notification.requestPermission((permission) => {
        confirmNotification(this.siteSettings);
        return permission === "granted";
      });
    }
  }
}
