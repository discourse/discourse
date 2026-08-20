import { ajax } from "discourse/lib/ajax";
import { helperContext } from "discourse/lib/helpers";
import KeyValueStore from "discourse/lib/key-value-store";

export const keyValueStore = new KeyValueStore("discourse_push_notifications_");

// a worker that failed to install never activates, so `ready` would hang; this
// bounds both the boot resync and the button press behind `enable()`
const SERVICE_WORKER_READY_TIMEOUT_MS = 5000;

export function userSubscriptionKey(user) {
  return `subscribed-${user.get("id")}`;
}

// The stored intent is the user's last expressed choice on this device; the
// actual subscription lives in the platform's PushManager and can be purged
// behind our back (common on iOS home screen apps).
// "subscribed" = wants push, "off" = explicitly disabled, null = unknown.
export function getSubscriptionIntent(user) {
  const value = keyValueStore.getItem(userSubscriptionKey(user));

  if (value === "subscribed") {
    return "subscribed";
  }

  // older builds stored the boolean `false` (stringified) on explicit disable
  if (value === "off" || value === "false") {
    return "off";
  }

  // older builds also stamped "" for every user without a subscription, so an
  // empty value carries no signal
  return null;
}

export function setSubscriptionIntent(user, intent) {
  if (intent) {
    keyValueStore.setItem(userSubscriptionKey(user), intent);
  } else {
    keyValueStore.remove(userSubscriptionKey(user));
  }
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

// Reports whether the server now knows about this subscription. Retried on the
// next boot, so a failure is logged rather than raised.
async function resyncSubscriptionWithServer(subscription) {
  try {
    await sendSubscriptionToServer(subscription, false);
    return true;
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return false;
  }
}

// `navigator.serviceWorker.ready` never rejects, so guard against
// environments where no service worker ever registers
function serviceWorkerRegistration() {
  return new Promise((resolve) => {
    const timer = setTimeout(
      () => resolve(null),
      SERVICE_WORKER_READY_TIMEOUT_MS
    );

    navigator.serviceWorker.ready.then((registration) => {
      clearTimeout(timer);
      resolve(registration);
    });
  });
}

export function isPushNotificationsSupported() {
  const caps = helperContext().capabilities;

  // deliberately no check that a service worker controls the page: right
  // after a (re-)install nothing does, and that is exactly when a purged
  // subscription needs to be restored
  return (
    "serviceWorker" in navigator &&
    typeof ServiceWorkerRegistration !== "undefined" &&
    typeof Notification !== "undefined" &&
    "showNotification" in ServiceWorkerRegistration.prototype &&
    "PushManager" in window &&
    !caps.isAppWebview
  );
}

export function listenForPushNotificationMessages(router, appEvents) {
  if (!isPushNotificationsSupported()) {
    return;
  }

  navigator.serviceWorker.addEventListener("message", (event) => {
    if ("url" in event.data) {
      router.transitionTo(event.data.url);
      appEvents.trigger("push-notification-opened", { url: event.data.url });
    }
  });
}

// Tells the server to forget this device's subscription. Scoped to the current
// user server-side, so it can never drop a row belonging to another account
// sharing the browser.
function retireServerSubscription(subscription) {
  return ajax("/push_notifications/unsubscribe", {
    type: "POST",
    data: { subscription: subscription.toJSON() },
  }).catch((e) => {
    // eslint-disable-next-line no-console
    console.error(e);
  });
}

// Reconciles the device's actual push subscription with the user's stored
// intent.
//
// Returns "subscribed" when a subscription exists (or was restored), "lost"
// when the user has to opt in again, and null when there was nothing to
// conclude — a transient failure, so the intent is kept and the next boot
// retries.
export async function reconcileSubscription(
  user,
  { resubscribe = false, applicationServerKey } = {}
) {
  if (!user || !isPushNotificationsSupported()) {
    return null;
  }

  const intent = getSubscriptionIntent(user);
  if (intent === null) {
    return null;
  }

  const registration = await serviceWorkerRegistration();
  if (!registration) {
    return null;
  }

  let subscription;
  try {
    subscription = await registration.pushManager.getSubscription();
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return null;
  }

  if (intent === "off") {
    // The browser subscription is deliberately left alone: only one exists per
    // origin, so on a shared browser it may now belong to whoever subscribed
    // most recently. Retiring our own server row is what actually stops
    // delivery, and it retries here because the teardown at the time may have
    // failed offline.
    if (subscription) {
      await retireServerSubscription(subscription);
    }
    return null;
  }

  // A subscription the browser refuses to display is not a working one, so a
  // revoked grant counts as a loss whether or not the subscription object
  // itself survived.
  if (Notification.permission !== "granted") {
    setSubscriptionIntent(user, null);
    return "lost";
  }

  if (subscription) {
    return (await resyncSubscriptionWithServer(subscription))
      ? "subscribed"
      : null;
  }

  // The platform dropped the subscription but the grant survived, so it can be
  // restored with no prompt and no UI — the common case on iOS home screen
  // apps.

  if (!resubscribe) {
    return null;
  }

  try {
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: new Uint8Array(applicationServerKey.split("|")),
    });
  } catch (e) {
    // a failed restore is not an opt-out: keep the intent and retry next boot
    // eslint-disable-next-line no-console
    console.error(e);
    return null;
  }

  return (await resyncSubscriptionWithServer(subscription))
    ? "subscribed"
    : null;
}

export function subscribe(callback, applicationServerKey) {
  if (!isPushNotificationsSupported()) {
    return;
  }

  return serviceWorkerRegistration().then((registration) => {
    if (!registration) {
      return false;
    }

    return registration.pushManager
      .subscribe({
        userVisibleOnly: true,
        applicationServerKey: new Uint8Array(applicationServerKey.split("|")),
      })
      .then((subscription) => {
        sendSubscriptionToServer(subscription, true).catch((e) => {
          // eslint-disable-next-line no-console
          console.error(e);
        });
        callback?.();
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

  setSubscriptionIntent(user, "off");

  return serviceWorkerRegistration().then((registration) => {
    registration?.pushManager
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

    callback?.();
    return true;
  });
}
