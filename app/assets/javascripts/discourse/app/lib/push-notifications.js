import { ajax } from "discourse/lib/ajax";
import { helperContext } from "discourse/lib/helpers";
import KeyValueStore from "discourse/lib/key-value-store";

export const keyValueStore = new KeyValueStore("discourse_push_notifications_");

export function userSubscriptionKey(user) {
  return `subscribed-${user.get("id")}`;
}

function sendSubscriptionToServer(subscription, sendConfirmation) {
  ajax("/push_notifications/subscribe", {
    type: "POST",
    data: {
      subscription: subscription.toJSON(),
      send_confirmation: sendConfirmation,
    },
  });
}

export const PushNotificationSupport = {
  Supported: "Supported",
  PWARequired: "PWARequired", // Push notifications are supported when the app is installed as a PWA.
  NotSupported: "NotSupported"
};

export async function isPushNotificationsSupported() {
  let caps = helperContext().capabilities;

  if (caps.isAppWebview) {
    return PushNotificationSupport.NotSupported;
  }

  if (!("serviceWorker" in navigator) ||
    typeof ServiceWorkerRegistration === "undefined" ||
    typeof Notification === "undefined") {
    return PushNotificationSupport.NotSupported;
  }

  // Wait for the service worker to be ready.
  const registration = await navigator.serviceWorker.ready;

  // On iOS, push notifications are only supported when the app is running as a PWA.
  // https://github.com/andreinwald/webpush-ios-example/blob/75a4e707046ebf7f3b88cc1bbbb8aedecc4cf377/frontend.js#L24-L36
  if (!registration.pushManager) {
    if (!window.navigator.standalone) {
      // Not running in standalone mode? A PWA is probably needed.
      return PushNotificationSupport.PWARequired;
    }
  }

  return PushNotificationSupport.Supported;
}

export async function isPushNotificationsEnabled(user) {
  return (
    user &&
    !user.isInDoNotDisturb() &&
    await isPushNotificationsSupported() == PushNotificationSupport.Supported &&
    keyValueStore.getItem(userSubscriptionKey(user))
  );
}

// Register an existing subscription with the backend.
export async function register(user, router, appEvents) {
  if (await isPushNotificationsSupported() != PushNotificationSupport.Supported) {
    return;
  }
  if (Notification.permission === "denied" || !user) {
    return;
  }

  // Wait for the service worker to be ready.
  const serviceWorkerRegistration = await navigator.serviceWorker.ready;
  const subscription = await serviceWorkerRegistration.pushManager.getSubscription();

  if (subscription) {
    sendSubscriptionToServer(subscription, false);
    // Resync localStorage
    keyValueStore.setItem(userSubscriptionKey(user), "subscribed");
    navigator.serviceWorker.addEventListener("message", (event) => {
      if ("url" in event.data) {
        router.transitionTo(event.data.url);
        appEvents.trigger("push-notification-opened", { url: event.data.url });
      }
    });
  }
}

export async function subscribe(callback, applicationServerKey) {
  if (await isPushNotificationsSupported() != PushNotificationSupport.Supported) {
    return;
  }

  // Wait for the service worker to be ready.
  const serviceWorkerRegistration = await navigator.serviceWorker.ready;
  const subscription = await serviceWorkerRegistration.pushManager
    .subscribe({
      userVisibleOnly: true,
      applicationServerKey: new Uint8Array(applicationServerKey.split("|")),
    });

  if (subscription) {
    sendSubscriptionToServer(subscription, true);
    if (callback) {
      callback();
    }
    return true;
  }

  return false;
}

export async function unsubscribe(user, callback) {
  if (await isPushNotificationsSupported() != PushNotificationSupport.Supported) {
    return;
  }

  // Wait for the service worker to be ready.
  const serviceWorkerRegistration = await navigator.serviceWorker.ready;
  const subscription = await serviceWorkerRegistration.pushManager.getSubscription();

  if (subscription) {
    keyValueStore.setItem(userSubscriptionKey(user), "");

    subscription.unsubscribe().then((successful) => {
      if (successful) {
        ajax("/push_notifications/unsubscribe", {
          type: "POST",
          data: { subscription: subscription.toJSON() },
        });
      }
    });

    if (callback) {
      callback();
    }

    return true;
  } else {
    return false;
  }
}
