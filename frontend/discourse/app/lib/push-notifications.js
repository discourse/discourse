import { ajax } from "discourse/lib/ajax";
import { helperContext } from "discourse/lib/helpers";
import KeyValueStore from "discourse/lib/key-value-store";

export const keyValueStore = new KeyValueStore("discourse_push_notifications_");
export const consentPromptDismissedKey = "dismissed-prompt";

export function userSubscriptionKey(user) {
  return `subscribed-${user.get("id")}`;
}

function sendSubscriptionToServer(subscription, sendConfirmation) {
  return ajax("/push_notifications/subscribe", {
    type: "POST",
    data: {
      subscription: subscription.toJSON(),
      send_confirmation: sendConfirmation,
    },
  });
}

export function isPushNotificationsSupported() {
  let caps = helperContext().capabilities;
  if (
    !(
      "serviceWorker" in navigator &&
      typeof ServiceWorkerRegistration !== "undefined" &&
      typeof Notification !== "undefined" &&
      "showNotification" in ServiceWorkerRegistration.prototype &&
      "PushManager" in window &&
      !caps.isAppWebview &&
      navigator.serviceWorker.controller &&
      navigator.serviceWorker.controller.state === "activated"
    )
  ) {
    return false;
  }

  return true;
}

export function isPushNotificationsEnabled(user) {
  return (
    user &&
    !user.isInDoNotDisturb() &&
    isPushNotificationsSupported() &&
    keyValueStore.getItem(userSubscriptionKey(user)) === "subscribed"
  );
}

function pushSubscriptionOptions(applicationServerKey) {
  return {
    userVisibleOnly: true,
    applicationServerKey: new Uint8Array(applicationServerKey.split("|")),
  };
}

export function register(user, router, appEvents, applicationServerKey) {
  if (!isPushNotificationsSupported()) {
    return;
  }
  if (Notification.permission === "denied" || !user) {
    return;
  }

  navigator.serviceWorker.addEventListener("message", (event) => {
    if ("url" in event.data) {
      router.transitionTo(event.data.url);
      appEvents.trigger("push-notification-opened", { url: event.data.url });
    }
  });

  return navigator.serviceWorker.ready.then(
    async (serviceWorkerRegistration) => {
      const { pushManager } = serviceWorkerRegistration;
      let subscription;

      try {
        subscription = await pushManager.getSubscription();
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error(e);
        // the existing subscription may still deliver
        return true;
      }

      if (subscription) {
        sendSubscriptionToServer(subscription, false);
        return true;
      }

      if (keyValueStore.getItem(userSubscriptionKey(user)) !== "subscribed") {
        return true;
      }

      // Browsers can drop a subscription while keeping the permission
      try {
        subscription = await pushManager.subscribe(
          pushSubscriptionOptions(applicationServerKey)
        );

        // push was turned off while subscribing
        if (keyValueStore.getItem(userSubscriptionKey(user)) !== "subscribed") {
          await subscription.unsubscribe();
          return true;
        }

        // the new endpoint delivers nothing until the server knows it
        await sendSubscriptionToServer(subscription, false);
        return true;
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error(e);
        return false;
      }
    }
  );
}

export function subscribe(callback, applicationServerKey) {
  if (!isPushNotificationsSupported()) {
    return;
  }

  return navigator.serviceWorker.ready.then((serviceWorkerRegistration) => {
    return serviceWorkerRegistration.pushManager
      .subscribe(pushSubscriptionOptions(applicationServerKey))
      .then((subscription) => {
        sendSubscriptionToServer(subscription, true);
        if (callback) {
          callback();
        }
        return true;
      })
      .catch((e) => {
        // eslint-disable-next-line no-console
        console.error(e);
        return false;
      });
  });
}

export async function getCurrentPushSubscription() {
  if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
    return null;
  }

  try {
    const registration = await navigator.serviceWorker.getRegistration();
    if (!registration) {
      return null;
    }
    const subscription = await registration.pushManager.getSubscription();
    return subscription ? subscription.toJSON() : null;
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return null;
  }
}

export function unsubscribe(user, callback) {
  if (!isPushNotificationsSupported()) {
    return;
  }

  keyValueStore.setItem(userSubscriptionKey(user), "");
  return navigator.serviceWorker.ready.then((serviceWorkerRegistration) => {
    serviceWorkerRegistration.pushManager
      .getSubscription()
      .then((subscription) => {
        if (subscription) {
          subscription.unsubscribe().then((successful) => {
            if (successful) {
              ajax("/push_notifications/unsubscribe", {
                type: "POST",
                data: { subscription: subscription.toJSON() },
              });
            }
          });
        }
      })
      .catch((e) => {
        // eslint-disable-next-line no-console
        console.error(e);
      });

    if (callback) {
      callback();
    }
    return true;
  });
}
