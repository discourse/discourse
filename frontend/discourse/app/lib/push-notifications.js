import { ajax } from "discourse/lib/ajax";
import { helperContext } from "discourse/lib/helpers";
import KeyValueStore from "discourse/lib/key-value-store";

export const keyValueStore = new KeyValueStore("discourse_push_notifications_");
export const pushNotificationPreferenceStore = new KeyValueStore(
  "push_notification_preferences_"
);

// a worker that failed to install never activates, so `ready` would hang
const SERVICE_WORKER_READY_TIMEOUT_MS = 5000;
const ADOPTION_IN_PROGRESS = "adopting";

export function userSubscriptionKey(user) {
  return `subscribed-${user.get("id")}`;
}

// The user's last expressed choice on this device; the platform's actual
// subscription can be purged behind our back (common on iOS home screen apps).
export function getSubscriptionIntent(user) {
  const key = userSubscriptionKey(user);
  if (pushNotificationPreferenceStore.getItem(key) === "off") {
    return "off";
  }

  const value = keyValueStore.getItem(key);

  if (value === "subscribed") {
    return "subscribed";
  }

  // older builds stored the boolean `false` (stringified) on explicit disable
  if (value === "off" || value === "false") {
    pushNotificationPreferenceStore.setItem(key, "off");
    keyValueStore.remove(key);
    return "off";
  }

  // older builds also stamped "" for every user without a subscription, so an
  // empty value carries no signal
  return null;
}

export function setSubscriptionIntent(user, intent) {
  const key = userSubscriptionKey(user);

  if (intent === "off") {
    pushNotificationPreferenceStore.setItem(key, "off");
    keyValueStore.remove(key);
  } else if (intent === "subscribed") {
    pushNotificationPreferenceStore.remove(key);
    keyValueStore.setItem(key, intent);
  } else {
    keyValueStore.remove(key);
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

// retried on the next boot, so a failure is logged rather than raised
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

// Scoped to the current user server-side, so it can never drop a row
// belonging to another account sharing the browser.
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

// The POST recreates the server row, so an opt-out or logout that landed while
// it was in flight has to be replayed against it.
async function confirmResync(user, subscription, previousIntent) {
  const currentIntent = getSubscriptionIntent(user);
  const storedIntent = keyValueStore.getItem(userSubscriptionKey(user));
  if (
    currentIntent === "off" ||
    (previousIntent === "subscribed" && currentIntent === null) ||
    (previousIntent === null &&
      currentIntent === null &&
      storedIntent !== ADOPTION_IN_PROGRESS)
  ) {
    await retireServerSubscription(subscription);
    return null;
  }

  setSubscriptionIntent(user, "subscribed");
  return "subscribed";
}

// Returns the verified state, "lost" when permission vanished, or null when no
// conclusion was possible.
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

  if (intent === "off") {
    // Only drop the platform subscription once the server row is gone: it is
    // the sole way back to that row if the request failed.
    if (subscription && (await retireServerSubscription(subscription))) {
      const currentIntent = getSubscriptionIntent(user);
      if (currentIntent === "off") {
        await discardPlatformSubscription(subscription);
      } else if (
        currentIntent === "subscribed" &&
        (await resyncSubscriptionWithServer(subscription))
      ) {
        return await confirmResync(user, subscription, currentIntent);
      }
    }
    return null;
  }

  // A subscription the browser refuses to display is not a working one, so a
  // revoked grant counts as a loss whether or not the subscription object
  // itself survived.
  if (Notification.permission !== "granted") {
    if (intent === "subscribed") {
      setSubscriptionIntent(user, null);
      return "lost";
    }
    return null;
  }

  if (subscription) {
    if (intent === null) {
      if (!resubscribe) {
        return null;
      }
      keyValueStore.setItem(userSubscriptionKey(user), ADOPTION_IN_PROGRESS);
    }

    if (await resyncSubscriptionWithServer(subscription)) {
      return await confirmResync(user, subscription, intent);
    }

    if (
      keyValueStore.getItem(userSubscriptionKey(user)) === ADOPTION_IN_PROGRESS
    ) {
      setSubscriptionIntent(user, null);
    }

    return null;
  }

  // The origin-level grant is the opt-in. Restore for every account except
  // those which explicitly opted out.
  if (!resubscribe || !applicationServerKey) {
    return null;
  }

  if (intent === null) {
    keyValueStore.setItem(userSubscriptionKey(user), ADOPTION_IN_PROGRESS);
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
    if (
      keyValueStore.getItem(userSubscriptionKey(user)) === ADOPTION_IN_PROGRESS
    ) {
      keyValueStore.remove(userSubscriptionKey(user));
    }
    return null;
  }

  if (await resyncSubscriptionWithServer(subscription)) {
    return await confirmResync(user, subscription, intent);
  }

  // Left in place: only one subscription exists per origin, so discarding it can
  // destroy one another tab just confirmed. It stays unacknowledged, so the next
  // boot keeps the fallback and resyncs this same endpoint.
  if (
    keyValueStore.getItem(userSubscriptionKey(user)) === ADOPTION_IN_PROGRESS
  ) {
    keyValueStore.remove(userSubscriptionKey(user));
  }
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
