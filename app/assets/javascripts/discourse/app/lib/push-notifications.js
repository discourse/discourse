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
    keyValueStore.getItem(userSubscriptionKey(user))
  );
}

export function register(user, router, appEvents) {
  if (!isPushNotificationsSupported()) {
    return;
  }
  if (Notification.permission === "denied" || !user) {
    return;
  }

  navigator.serviceWorker.ready.then((serviceWorkerRegistration) => {
    serviceWorkerRegistration.pushManager
      .getSubscription()
      .then((subscription) => {
        if (subscription) {
          sendSubscriptionToServer(subscription, false);
          // Resync localStorage
          keyValueStore.setItem(userSubscriptionKey(user), "subscribed");
        }
      })
      .catch((e) => {
        // eslint-disable-next-line no-console
        console.error(e);
      });
  });

  navigator.serviceWorker.addEventListener("message", (event) => {
    if ("url" in event.data) {
      router.transitionTo(event.data.url);
      appEvents.trigger("push-notification-opened", { url: event.data.url });
    }
  });
}

export function subscribe(callback, applicationServerKey) {
  if (!isPushNotificationsSupported()) {
    return;
  }

  return navigator.serviceWorker.ready.then((serviceWorkerRegistration) => {
    return serviceWorkerRegistration.pushManager
      .subscribe({
        userVisibleOnly: true,
        applicationServerKey: new Uint8Array(applicationServerKey.split("|")),
      })
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
