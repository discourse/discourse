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

// "unconfirmed" is only safe for an endpoint the server acknowledged in an
// earlier session. A brand-new one it never answered for must keep the in-tab
// fallback alive, or a device whose row was never created goes silent.
function confirmedEndpointKey(user) {
  return `confirmed-endpoint-${user.get("id")}`;
}

function markEndpointConfirmed(user, subscription) {
  keyValueStore.setItem(
    confirmedEndpointKey(user),
    subscription.toJSON().endpoint
  );
}

function isEndpointConfirmed(user, subscription) {
  return (
    keyValueStore.getItem(confirmedEndpointKey(user)) ===
    subscription.toJSON().endpoint
  );
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
async function retireServerSubscription(subscription) {
  try {
    await ajax("/push_notifications/unsubscribe", {
      type: "POST",
      data: { subscription: subscription.toJSON() },
    });
    return true;
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return false;
  }
}

async function discardPlatformSubscription(subscription) {
  try {
    await subscription.unsubscribe();
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
  }
}

// Reconciles the device's actual push subscription with the user's stored
// intent.
//
// Returns "subscribed" when the server knows about a working subscription,
// "unconfirmed" when the device still has the one it was told about earlier but
// the resync could not reach the server, "lost" when the user has to opt in
// again, and null when there was nothing to conclude — a transient failure, so
// the intent is kept and the next boot retries.
export async function reconcileSubscription(
  user,
  { resubscribe = false, applicationServerKey } = {}
) {
  if (!user || !isPushNotificationsSupported()) {
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

  // Re-read: `enable()` can record an intent while the awaits above are still
  // pending, and the branches below destroy subscriptions.
  const intent = getSubscriptionIntent(user);

  if (intent === null) {
    if (subscription) {
      // An origin has only one subscription. With no current-user intent its
      // ownership cannot be verified, so retaining it could expose another
      // account's notifications after an abnormal session replacement.
      await discardPlatformSubscription(subscription);
    }
    return null;
  }

  if (intent === "off") {
    // Only drop the platform subscription once the server row is gone: it is
    // the sole way back to that row if the request failed.
    if (subscription && (await retireServerSubscription(subscription))) {
      await discardPlatformSubscription(subscription);
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
    if (await resyncSubscriptionWithServer(subscription)) {
      markEndpointConfirmed(user, subscription);
      return "subscribed";
    }

    // A failed request is not proof the row is missing, so an endpoint the
    // server acknowledged before still counts as delivering.
    return isEndpointConfirmed(user, subscription) ? "unconfirmed" : null;
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

  if (await resyncSubscriptionWithServer(subscription)) {
    markEndpointConfirmed(user, subscription);
    return "subscribed";
  }

  // Left in place: only one subscription exists per origin, so discarding it can
  // destroy one another tab just confirmed. It stays unacknowledged, so the next
  // boot keeps the fallback and resyncs this same endpoint.
  return null;
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
      .then(async (subscription) => {
        // a subscription the server never recorded receives nothing, so it
        // must not be reported as enabled
        await sendSubscriptionToServer(subscription, true);
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

export async function unsubscribe(user, callback) {
  setSubscriptionIntent(user, "off");

  if (!isPushNotificationsSupported()) {
    callback?.();
    return true;
  }

  const registration = await serviceWorkerRegistration();

  try {
    const subscription = await registration?.pushManager.getSubscription();

    if (subscription) {
      // The row is retired first and unconditionally: `unsubscribe()` resolves
      // false for an already-dropped subscription, and the endpoint is the only
      // handle on that row, so it is kept until the row is actually gone.
      if (await retireServerSubscription(subscription)) {
        await subscription.unsubscribe();
      }
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
  }

  callback?.();
  return true;
}
