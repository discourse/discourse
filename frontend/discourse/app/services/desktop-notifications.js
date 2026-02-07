import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import {
  confirmNotification,
  context,
} from "discourse/lib/desktop-notifications";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import KeyValueStore from "discourse/lib/key-value-store";
import {
  isPushNotificationsSupported,
  keyValueStore as pushNotificationKeyValueStore,
  PushNotificationSupport,
  pushNotificationSupport,
  subscribe as subscribePushNotification,
  unsubscribe as unsubscribePushNotification,
  userSubscriptionKey as pushNotificationUserSubscriptionKey,
} from "discourse/lib/push-notifications";

const keyValueStore = new KeyValueStore(context);
const DISABLED = "disabled";
const ENABLED = "enabled";
const SUBSCRIBED = "subscribed";

@disableImplicitInjections
export default class DesktopNotificationsService extends Service {
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked isEnabledBrowser = false;
  @tracked isEnabledPush = false;

  constructor() {
    super(...arguments);

    if (this.isPushNotificationsPreferred) {
      this.isEnabledPush = this.currentUser
        ? pushNotificationKeyValueStore.getItem(
            pushNotificationUserSubscriptionKey(this.currentUser)
          ) === SUBSCRIBED
        : false;

      // N.B: If push notifications are preferred, treat them as superseding regular browser
      // notifications and disable the latter.
      this.setIsEnabledBrowser(false);
    }

    this.isEnabledBrowser = this.isGrantedPermission
      ? keyValueStore.getItem("notifications-disabled") === ENABLED
      : false;
  }

  get isSupported() {
    return typeof window.Notification !== "undefined";
  }

  get isNotSupported() {
    return !this.isSupported;
  }

  get isPushSupported() {
    return isPushNotificationsSupported();
  }

  get isPushPwaNeeded() {
    return pushNotificationSupport() === PushNotificationSupport.PWARequired;
  }

  get notificationsPermission() {
    return this.isNotSupported ? "" : Notification.permission;
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

  get isEnabled() {
    return this.isEnabledPush || this.isEnabledBrowser;
  }

  get isSubscribed() {
    if (!this.isEnabled) {
      return false;
    }

    return this.isPushNotificationsPreferred
      ? this.isEnabledPush
      : this.isEnabledBrowser;
  }

  // Returns whether or not push notifications are preferred (but notably, does _NOT_
  // check to see whether or not they are supported).
  get isPushNotificationsPreferred() {
    return (
      this.site.mobileView ||
      this.siteSettings.enable_desktop_push_notifications
    );
  }

  setIsEnabledBrowser(value) {
    const status = value ? ENABLED : DISABLED;
    keyValueStore.setItem("notifications-disabled", status);
    this.isEnabledBrowser = value;
  }

  setIsEnabledPush(value) {
    const user = this.currentUser;
    const status = value ? SUBSCRIBED : value;

    if (!user) {
      return false;
    }

    pushNotificationKeyValueStore.setItem(
      pushNotificationUserSubscriptionKey(user),
      status
    );

    this.isEnabledPush = value;
  }

  @action
  async disable() {
    if (this.isEnabledBrowser) {
      this.setIsEnabledBrowser(false);
    }
    if (this.isEnabledPush) {
      await unsubscribePushNotification(this.currentUser, () => {
        this.setIsEnabledPush(false);
      });
    }

    return true;
  }

  @action
  async enable() {
    // If notifications are supported, attempt to:
    // 1) enable browser notifications
    // 2) subscribe to push notifications.
    if (this.isSupported) {
      if (!this.isGrantedPermission) {
        // This permission also applies to webpush notifications.
        // https://stackoverflow.com/q/46551259
        await Notification.requestPermission();
      }

      if (this.isDeniedPermission) {
        // User has denied permission for sending notifications.
        return false;
      }

      if (this.isPushNotificationsPreferred) {
        switch (pushNotificationSupport()) {
          case PushNotificationSupport.Supported:
            // Subscribe to push notifications from the server. If successful, a notification will be sent.
            await subscribePushNotification(() => {
              this.setIsEnabledPush(true);
            }, this.siteSettings.vapid_public_key_bytes);

            return true;
          case PushNotificationSupport.PWARequired:
            // User must install the application as a PWA.
            return false;
          case PushNotificationSupport.NotSupported:
          default:
            // Push notifications not supported.
            return false;
        }
      } else {
        // Push notifications not preferred; so generate a confirmation notification.
        confirmNotification(this.siteSettings);
        this.setIsEnabledBrowser(true);

        return true;
      }
    }

    return false;
  }
}
