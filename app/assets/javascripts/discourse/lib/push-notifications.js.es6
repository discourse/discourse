import { ajax } from "discourse/lib/ajax";
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
      send_confirmation: sendConfirmation
    }
  });
}

function userAgentVersionChecker(agent, version, mobileView) {
  const uaMatch = navigator.userAgent.match(
    new RegExp(`${agent}\/(\\d+)\\.\\d`)
  );
  if (uaMatch && mobileView) return false;
  if (!uaMatch || parseInt(uaMatch[1], 10) < version) return false;
  return true;
}

function resetIdle() {
  if (
    "controller" in navigator.serviceWorker &&
    navigator.serviceWorker.controller != null
  ) {
    navigator.serviceWorker.controller.postMessage({ lastAction: Date.now() });
  }
}

function setupActivityListeners(appEvents) {
  window.addEventListener("focus", resetIdle);

  if (document) {
    document.addEventListener("scroll", resetIdle);
  }

  appEvents.on("page:changed", resetIdle);
}

export function isPushNotificationsSupported(mobileView) {
  if (
    !(
      "serviceWorker" in navigator &&
      ServiceWorkerRegistration &&
      typeof Notification !== "undefined" &&
      "showNotification" in ServiceWorkerRegistration.prototype &&
      "PushManager" in window
    )
  ) {
    return false;
  }

  if (
    !userAgentVersionChecker("Firefox", 44, mobileView) &&
    !userAgentVersionChecker("Chrome", 50)
  ) {
    return false;
  }

  return true;
}

export function isPushNotificationsEnabled(user, mobileView) {
  return (
    user &&
    isPushNotificationsSupported(mobileView) &&
    keyValueStore.getItem(userSubscriptionKey(user))
  );
}

export function register(user, mobileView, router, appEvents) {
  if (!isPushNotificationsSupported(mobileView)) return;
  if (Notification.permission === "denied" || !user) return;

  navigator.serviceWorker.ready.then(serviceWorkerRegistration => {
    serviceWorkerRegistration.pushManager
      .getSubscription()
      .then(subscription => {
        if (subscription) {
          sendSubscriptionToServer(subscription, false);
          // Resync localStorage
          keyValueStore.setItem(userSubscriptionKey(user), "subscribed");
        }
        setupActivityListeners(appEvents);
      })
      .catch(e => {
        // eslint-disable-next-line no-console
        console.error(e);
      });
  });

  navigator.serviceWorker.addEventListener("message", event => {
    if ("url" in event.data) {
      const url = event.data.url;
      router.handleURL(url);
    }
  });
}

export function subscribe(callback, applicationServerKey, mobileView) {
  if (!isPushNotificationsSupported(mobileView)) return;

  navigator.serviceWorker.ready.then(serviceWorkerRegistration => {
    serviceWorkerRegistration.pushManager
      .subscribe({
        userVisibleOnly: true,
        applicationServerKey: new Uint8Array(applicationServerKey.split("|")) // eslint-disable-line no-undef
      })
      .then(subscription => {
        sendSubscriptionToServer(subscription, true);
        if (callback) callback();
      })
      .catch(e => {
        // eslint-disable-next-line no-console
        console.error(e);
      });
  });
}

export function unsubscribe(user, callback, mobileView) {
  if (!isPushNotificationsSupported(mobileView)) return;

  keyValueStore.setItem(userSubscriptionKey(user), "");
  navigator.serviceWorker.ready.then(serviceWorkerRegistration => {
    serviceWorkerRegistration.pushManager
      .getSubscription()
      .then(subscription => {
        if (subscription) {
          subscription.unsubscribe().then(successful => {
            if (successful) {
              ajax("/push_notifications/unsubscribe", {
                type: "POST",
                data: { subscription: subscription.toJSON() }
              });
            }
          });
        }
      })
      .catch(e => {
        // eslint-disable-next-line no-console
        console.error(e);
      });

    if (callback) callback();
  });
}
