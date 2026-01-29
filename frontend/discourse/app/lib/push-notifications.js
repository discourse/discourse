import { ajax } from "discourse/lib/ajax";
import { helperContext } from "discourse/lib/helpers";
import KeyValueStore from "discourse/lib/key-value-store";
import { getServiceWorkerRegistration } from "discourse/lib/register-service-worker";

export const keyValueStore = new KeyValueStore("discourse_push_notifications_");

export function userSubscriptionKey(user) {
  return `subscribed-${user.get("id")}`;
}

export const PushNotificationSupport = {
  Supported: "Supported",
  PWARequired: "PWARequired", // (iOS only) Push notifications are supported when the app is installed as a PWA.
  NotSupported: "NotSupported",
};

export function isPushNotificationsSupported() {
  return pushNotificationSupport() === PushNotificationSupport.Supported;
}

export function pushNotificationSupport() {
  let caps = helperContext().capabilities;

  if (caps.isAppWebview) {
    // DiscourseHub app. This implements notifications via native APIs.
    return PushNotificationSupport.NotSupported;
  }

  if (
    !("serviceWorker" in navigator) ||
    typeof ServiceWorkerRegistration === "undefined"
  ) {
    return PushNotificationSupport.NotSupported;
  }

  const registration = getServiceWorkerRegistration();
  if (!registration) {
    return PushNotificationSupport.NotSupported;
  }

  // On iOS, push notifications are only supported when the app is running as a PWA.
  // https://github.com/andreinwald/webpush-ios-example/blob/75a4e707046ebf7f3b88cc1bbbb8aedecc4cf377/frontend.js#L24-L36
  if (!registration.pushManager) {
    if (!window.navigator.standalone) {
      // Not running in standalone mode? A PWA is probably needed.
      return PushNotificationSupport.PWARequired;
    }

    // Not really sure how we can reach this point, but just in-case.
    return PushNotificationSupport.NotSupported;
  }

  // As a final sanity check, see if `Notification` is implemented. We should typically never hit this.
  if (typeof Notification === "undefined") {
    return PushNotificationSupport.NotSupported;
  }

  return PushNotificationSupport.Supported;
}

export function isPushNotificationsEnabled(user) {
  return (
    user &&
    !user.isInDoNotDisturb() &&
    isPushNotificationsSupported() &&
    keyValueStore.getItem(userSubscriptionKey(user))
  );
}

// Register an existing subscription with the backend.
export async function register(user, router, appEvents) {
  if (!isPushNotificationsSupported()) {
    return;
  }
  if (Notification.permission === "denied" || !user) {
    return;
  }

  const registration = getServiceWorkerRegistration();
  const subscription = await registration.pushManager.getSubscription();

  if (!subscription) {
    // No active subscription, so nothing to do.
    return;
  }

  ajax("/push_notifications/subscribe", {
    type: "POST",
    data: {
      subscription: subscription.toJSON(),
      send_confirmation: false, // Do not send a confirmation notification.
    },
  }).catch((e) => {
    // eslint-disable-next-line no-console
    console.error(e);
  });

  // Resync localStorage
  keyValueStore.setItem(userSubscriptionKey(user), "subscribed");
  navigator.serviceWorker.addEventListener("message", (event) => {
    if ("url" in event.data) {
      router.transitionTo(event.data.url);
      appEvents.trigger("push-notification-opened", { url: event.data.url });
    }
  });
}

export async function subscribe(callback, applicationServerKey) {
  if (!isPushNotificationsSupported()) {
    return;
  }

  // Wait for the service worker to be ready.
  const serviceWorkerRegistration = await navigator.serviceWorker.ready;
  const subscription = await serviceWorkerRegistration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: new Uint8Array(applicationServerKey.split("|")),
  });

  if (subscription) {
    ajax("/push_notifications/subscribe", {
      type: "POST",
      data: {
        subscription: subscription.toJSON(),
        send_confirmation: true, // Have the backend send a confirmation notification.
      },
    })
      .then(() => {
        if (callback) {
          callback();
        }
      })
      .catch((e) => {
        // eslint-disable-next-line no-console
        console.error(e);
      });

    return true;
  }

  return false;
}

export async function unsubscribe(user, callback) {
  if (!isPushNotificationsSupported()) {
    return;
  }

  const registration = getServiceWorkerRegistration();
  const subscription = await registration.pushManager.getSubscription();

  if (!subscription) {
    return false;
  }

  keyValueStore.setItem(userSubscriptionKey(user), "");

  if (await subscription.unsubscribe()) {
    ajax("/push_notifications/unsubscribe", {
      type: "POST",
      data: { subscription: subscription.toJSON() },
    })
      .then(() => {
        if (callback) {
          callback();
        }
      })
      .catch((e) => {
        // eslint-disable-next-line no-console
        console.error(e);
      });
  } else {
    // eslint-disable-next-line no-console
    console.error("PushSubscription.unsubscribe() failed");
  }

  return true;
}
