import { ajax } from "discourse/lib/ajax";
import { helperContext } from "discourse/lib/helpers";
import KeyValueStore from "discourse/lib/key-value-store";

export const keyValueStore = new KeyValueStore("discourse_push_notifications_");
export const pushNotificationPreferenceStore = new KeyValueStore(
  "push_notification_preferences_"
);
export const pushNotificationConfirmationStore = new KeyValueStore(
  "push_notification_confirmation_"
);

// a worker that failed to install never activates, so `ready` would hang
const SERVICE_WORKER_READY_TIMEOUT_MS = 5000;
const ADOPTION_IN_PROGRESS = "adopting";
const CONFIRMED_SUBSCRIPTION_KEY = "active";
const SUBSCRIPTION_OPERATION_KEY = "operation";
let nextSubscriptionOperationId = 0;

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

function beginSubscriptionOperation(action) {
  const operation = `${action}-${Date.now()}-${++nextSubscriptionOperationId}`;
  keyValueStore.setItem(SUBSCRIPTION_OPERATION_KEY, operation);
  return operation;
}

function isCurrentSubscriptionOperation(operation) {
  return currentSubscriptionOperation() === operation;
}

function currentSubscriptionOperation() {
  return keyValueStore.getItem(SUBSCRIPTION_OPERATION_KEY);
}

function currentSubscriptionOperationAction() {
  return currentSubscriptionOperation()?.split("-", 1)[0];
}

function markEndpointConfirmed(user, subscription) {
  pushNotificationConfirmationStore.setObject({
    key: CONFIRMED_SUBSCRIPTION_KEY,
    value: {
      userId: user.get("id"),
      endpoint: subscription.toJSON().endpoint,
    },
  });
}

function isEndpointConfirmed(user, subscription) {
  const confirmation = pushNotificationConfirmationStore.getObject(
    CONFIRMED_SUBSCRIPTION_KEY
  );

  return (
    confirmation?.userId === user.get("id") &&
    confirmation.endpoint === subscription.toJSON().endpoint
  );
}

export function clearPushSubscriptionConfirmation(user, subscription) {
  const confirmation = pushNotificationConfirmationStore.getObject(
    CONFIRMED_SUBSCRIPTION_KEY
  );
  const endpoint = subscription?.toJSON
    ? subscription.toJSON().endpoint
    : subscription?.endpoint;

  if (
    confirmation?.userId === user.get("id") &&
    (!endpoint || confirmation.endpoint === endpoint)
  ) {
    pushNotificationConfirmationStore.remove(CONFIRMED_SUBSCRIPTION_KEY);
  }
}

export function clearPushSubscriptionConfirmationForOrigin() {
  pushNotificationConfirmationStore.remove(CONFIRMED_SUBSCRIPTION_KEY);
}

function sendSubscriptionToServer(user, subscription, sendConfirmation) {
  return ajax("/push_notifications/subscribe", {
    type: "POST",
    data: {
      user_id: user.get("id"),
      subscription: subscription.toJSON(),
      send_confirmation: sendConfirmation,
    },
  });
}

// retried on the next boot, so a failure is logged rather than raised
async function resyncSubscriptionWithServer(user, subscription) {
  try {
    await sendSubscriptionToServer(user, subscription, false);
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
async function retireServerSubscription(user, subscription) {
  try {
    await ajax("/push_notifications/unsubscribe", {
      type: "POST",
      data: { user_id: user.get("id"), subscription: subscription.toJSON() },
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
async function confirmResync(
  user,
  subscription,
  previousIntent,
  reconciliationOperation
) {
  const currentIntent = getSubscriptionIntent(user);
  const storedIntent = keyValueStore.getItem(userSubscriptionKey(user));
  if (
    currentIntent === "off" ||
    (previousIntent === "subscribed" && currentIntent === null) ||
    (previousIntent === null &&
      currentIntent === null &&
      storedIntent !== ADOPTION_IN_PROGRESS)
  ) {
    if (
      reconciliationOperation &&
      !isCurrentSubscriptionOperation(reconciliationOperation) &&
      currentSubscriptionOperationAction() === "enable"
    ) {
      return null;
    }

    if (await retireServerSubscription(user, subscription)) {
      clearPushSubscriptionConfirmation(user, subscription);
    }
    return null;
  }

  setSubscriptionIntent(user, "subscribed");
  markEndpointConfirmed(user, subscription);
  return "subscribed";
}

// Returns the verified state, "unconfirmed" for an endpoint acknowledged on an
// earlier boot, "lost" when permission vanished, or null when no conclusion was
// possible.
export async function reconcileSubscription(
  user,
  { resubscribe = false, applicationServerKey } = {}
) {
  if (!user || !isPushNotificationsSupported()) {
    return null;
  }

  const initialIntent = getSubscriptionIntent(user);
  let reconciliationOperation;
  if (
    resubscribe &&
    initialIntent !== "off" &&
    Notification.permission === "granted"
  ) {
    reconciliationOperation = beginSubscriptionOperation("enable");
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
    const operation = currentSubscriptionOperation();

    if (currentSubscriptionOperationAction() === "enable") {
      return null;
    }

    // Only drop the platform subscription once the server row is gone: it is
    // the sole way back to that row if the request failed.
    if (subscription && (await retireServerSubscription(user, subscription))) {
      clearPushSubscriptionConfirmation(user, subscription);
      if (
        currentSubscriptionOperation() !== operation ||
        currentSubscriptionOperationAction() === "enable"
      ) {
        return null;
      }

      const currentIntent = getSubscriptionIntent(user);
      if (currentIntent === "off") {
        await discardPlatformSubscription(subscription);
      } else if (
        currentIntent === "subscribed" &&
        (await resyncSubscriptionWithServer(user, subscription))
      ) {
        return await confirmResync(
          user,
          subscription,
          currentIntent,
          reconciliationOperation
        );
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

    if (await resyncSubscriptionWithServer(user, subscription)) {
      return await confirmResync(
        user,
        subscription,
        intent,
        reconciliationOperation
      );
    }

    if (
      keyValueStore.getItem(userSubscriptionKey(user)) === ADOPTION_IN_PROGRESS
    ) {
      setSubscriptionIntent(user, null);
    }

    return isEndpointConfirmed(user, subscription) ? "unconfirmed" : null;
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

  if (await resyncSubscriptionWithServer(user, subscription)) {
    return await confirmResync(
      user,
      subscription,
      intent,
      reconciliationOperation
    );
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

export function subscribe(user, callback, applicationServerKey) {
  if (!isPushNotificationsSupported()) {
    return;
  }

  const operation = beginSubscriptionOperation("enable");
  clearPushSubscriptionConfirmationForOrigin();

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
        await sendSubscriptionToServer(user, subscription, true);

        if (!isCurrentSubscriptionOperation(operation)) {
          if (currentSubscriptionOperationAction() === "disable") {
            if (await retireServerSubscription(user, subscription)) {
              clearPushSubscriptionConfirmation(user, subscription);
            }
            await discardPlatformSubscription(subscription);
          }
          return false;
        }

        markEndpointConfirmed(user, subscription);
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
  const operation = beginSubscriptionOperation("disable");
  setSubscriptionIntent(user, "off");

  if (!isPushNotificationsSupported()) {
    if (isCurrentSubscriptionOperation(operation)) {
      callback?.();
      return true;
    }
    return false;
  }

  const registration = await serviceWorkerRegistration();
  if (!registration) {
    return false;
  }

  try {
    const subscription = await registration.pushManager.getSubscription();

    if (subscription) {
      // The row is retired first and unconditionally: `unsubscribe()` resolves
      // false for an already-dropped subscription, and the endpoint is the only
      // handle on that row, so it is kept until the row is actually gone.
      if (!(await retireServerSubscription(user, subscription))) {
        return false;
      }
      if (!isCurrentSubscriptionOperation(operation)) {
        return false;
      }
      clearPushSubscriptionConfirmation(user, subscription);
      await subscription.unsubscribe();
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return false;
  }

  if (!isCurrentSubscriptionOperation(operation)) {
    return false;
  }

  callback?.();
  return true;
}
