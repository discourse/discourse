import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import {
  confirmNotification,
  context,
  setPushTransport,
} from "discourse/lib/desktop-notifications";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import KeyValueStore from "discourse/lib/key-value-store";
import {
  getSubscriptionIntent,
  isPushNotificationsSupported,
  keyValueStore as pushNotificationKeyValueStore,
  reconcileSubscription,
  setSubscriptionIntent,
  subscribe as subscribePushNotification,
  unsubscribe as unsubscribePushNotification,
} from "discourse/lib/push-notifications";
import { i18n } from "discourse-i18n";

const keyValueStore = new KeyValueStore(context);
const DISABLED = "disabled";
const ENABLED = "enabled";

// the dismissal used to be recorded once for the whole browser
const LEGACY_CONSENT_PROMPT_DISMISSED_KEY = "dismissed-prompt";

function consentPromptDismissedKey(user) {
  return `dismissed-prompt-${user.get("id")}`;
}

function readConsentPromptDismissed(user) {
  const userKey = consentPromptDismissedKey(user);
  const userDismissed = pushNotificationKeyValueStore.getItem(userKey);
  const legacyDismissed = pushNotificationKeyValueStore.getItem(
    LEGACY_CONSENT_PROMPT_DISMISSED_KEY
  );

  if (legacyDismissed) {
    pushNotificationKeyValueStore.setItem(userKey, "dismissed");
    pushNotificationKeyValueStore.remove(LEGACY_CONSENT_PROMPT_DISMISSED_KEY);
  }

  return Boolean(userDismissed || legacyDismissed);
}

@disableImplicitInjections
export default class DesktopNotificationsService extends Service {
  @service currentUser;
  @service site;
  @service siteSettings;
  @service toasts;

  @tracked isEnabledBrowser = false;
  @tracked pushIntent = null;
  // null until boot reconciliation reports back, so the UI does not flicker
  @tracked pushSubscriptionConfirmed = null;
  @tracked consentPromptDismissed = false;

  constructor() {
    super(...arguments);

    this.consentPromptDismissed = this.currentUser
      ? readConsentPromptDismissed(this.currentUser)
      : false;

    this.isEnabledBrowser = this.isGrantedPermission
      ? keyValueStore.getItem("notifications-disabled") === ENABLED
      : false;
    this.pushIntent = this.currentUser
      ? getSubscriptionIntent(this.currentUser)
      : null;
  }

  get isNotSupported() {
    return typeof window.Notification === "undefined";
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

  get isEnabledPush() {
    return (
      this.pushIntent === "subscribed" &&
      this.pushSubscriptionConfirmed !== false
    );
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

  get isPushNotificationsPreferred() {
    return (
      (this.site.mobileView ||
        this.siteSettings.enable_desktop_push_notifications) &&
      isPushNotificationsSupported()
    );
  }

  get pushNeedsAttention() {
    return (
      this.pushIntent !== "off" &&
      this.isGrantedPermission &&
      this.isPushNotificationsPreferred &&
      this.pushSubscriptionConfirmed === false
    );
  }

  setIsEnabledBrowser(value) {
    const status = value ? ENABLED : DISABLED;
    keyValueStore.setItem("notifications-disabled", status);
    this.isEnabledBrowser = value;
  }

  setIsEnabledPush(value) {
    if (!this.currentUser) {
      return false;
    }

    const intent = value ? "subscribed" : "off";
    setSubscriptionIntent(this.currentUser, intent);
    this.pushIntent = intent;
    this.pushSubscriptionConfirmed = value;
    if (value) {
      this.rearmConsentPrompt();
    }
  }

  dismissConsentPrompt() {
    if (!this.currentUser) {
      return;
    }

    pushNotificationKeyValueStore.setItem(
      consentPromptDismissedKey(this.currentUser),
      "dismissed"
    );
    this.consentPromptDismissed = true;
  }

  rearmConsentPrompt() {
    if (!this.currentUser) {
      return;
    }

    pushNotificationKeyValueStore.remove(
      consentPromptDismissedKey(this.currentUser)
    );
    this.consentPromptDismissed = false;
  }

  // Reconciles stored intent with platform/server state for transport and UI.
  async reconcilePushSubscription() {
    const result = await reconcileSubscription(this.currentUser, {
      resubscribe: this.isPushNotificationsPreferred,
      applicationServerKey: this.siteSettings.vapid_public_key_bytes,
    });

    if (result === "subscribed") {
      this.pushIntent = "subscribed";
      this.pushSubscriptionConfirmed = true;
    } else if (result === "lost") {
      this.pushIntent = null;
      this.pushSubscriptionConfirmed = false;
      this.rearmConsentPrompt();
    } else if (
      this.pushIntent !== "off" &&
      this.isGrantedPermission &&
      this.isPushNotificationsPreferred
    ) {
      this.pushSubscriptionConfirmed = false;
    }

    return result;
  }

  @action
  async disable() {
    if (this.isEnabledBrowser) {
      this.setIsEnabledBrowser(false);
    }
    if (this.pushIntent === "subscribed") {
      const disabled = await unsubscribePushNotification(
        this.currentUser,
        () => {
          this.setIsEnabledPush(false);
        }
      );
      if (!disabled) {
        return false;
      }
    }
    setPushTransport(null);

    return true;
  }

  // `Notification.requestPermission` needs the click's user activation, which
  // expires while awaiting the service worker, so permission is always asked
  // for first. Both the promise and the legacy callback form are handled, and a
  // rejection (no activation, insecure context) must not hang the caller.
  async requestPermission() {
    if (this.isGrantedPermission || this.isDeniedPermission) {
      return this.notificationsPermission;
    }

    try {
      return await new Promise((resolve, reject) => {
        const result = Notification.requestPermission(resolve);
        if (result?.then) {
          result.then(resolve, reject);
        }
      });
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e);
      return "default";
    }
  }

  @action
  async enable() {
    if ((await this.requestPermission()) !== "granted") {
      return false;
    }

    if (this.isPushNotificationsPreferred) {
      const subscribed = await subscribePushNotification(
        this.currentUser,
        () => {
          this.setIsEnabledPush(true);
        },
        this.siteSettings.vapid_public_key_bytes
      );

      if (subscribed) {
        setPushTransport("delivering");
      } else {
        this.pushSubscriptionConfirmed = false;
        this.toasts.error({
          duration: "short",
          data: {
            message: i18n("user.desktop_notifications.enable_failed"),
          },
        });
      }

      return subscribed;
    }

    confirmNotification(this.siteSettings);
    this.setIsEnabledBrowser(true);
    return true;
  }
}
