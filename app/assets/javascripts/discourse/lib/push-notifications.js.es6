// This method handles the removal of subscriptionId
// in Chrome 44 by concatenating the subscription Id
// to the subscription endpoint
// See https://developers.google.com/web/updates/2015/03/push-notificatons-on-the-open-web
function endpointWorkaround(pushSubscription) {
  // Make sure we only mess with GCM
  if (pushSubscription.endpoint.indexOf('https://android.googleapis.com/gcm/send') !== 0) {
    return pushSubscription.endpoint;
  }

  var mergedEndpoint = pushSubscription.endpoint;
  // Chrome 42 + 43 will not have the subscriptionId attached
  // to the endpoint.
  if (pushSubscription.subscriptionId &&
    pushSubscription.endpoint.indexOf(pushSubscription.subscriptionId) === -1) {
    // Handle version 42 where you have separate subId and Endpoint
    mergedEndpoint = pushSubscription.endpoint + '/' +
      pushSubscription.subscriptionId;
  }
  return mergedEndpoint;
}

function sendSubscriptionToServer(subscription) {
  Discourse.ajax('/push_notifications/subscribe', {
    type: 'POST',
    data: { endpoint: endpointWorkaround(subscription) }
  });
}

export function isPushNotificationsSupported() {
  return ('serviceWorker' in navigator) &&
         (ServiceWorkerRegistration &&
         ('showNotification' in ServiceWorkerRegistration.prototype) &&
         ('PushManager' in window));
}

export function register(callback) {
  if (!isPushNotificationsSupported()) {
    if (callback) callback();
    return;
  }

  navigator.serviceWorker.register('/push_service_worker.js').then(() => {
    if (Notification.permission === 'denied' || !Discourse.User.current()) return;

    navigator.serviceWorker.ready.then(serviceWorkerRegistration => {
      serviceWorkerRegistration.pushManager.getSubscription().then(subscription => {
        if (subscription) {
          sendSubscriptionToServer(subscription);
          // Resync localStorage
          localStorage.setItem('push-notification-subscribed', 'subscribed');
        } else {
          localStorage.setItem('push-notification-subscribed', '');
          if (callback) callback();
        }
      }).catch(e => Ember.Logger.error(e));
    });
  });
}

export function subscribe(callback) {
  if (!isPushNotificationsSupported()) return;

  navigator.serviceWorker.ready.then(serviceWorkerRegistration => {
    serviceWorkerRegistration.pushManager.subscribe({ userVisibleOnly: true }).then(subscription => {
      sendSubscriptionToServer(subscription);
      if (callback) callback();
    }).catch(e => Ember.Logger.error(e));
  });
}

export function unsubscribe(callback) {
  if (!isPushNotificationsSupported()) return;

  navigator.serviceWorker.ready.then(serviceWorkerRegistration => {
    serviceWorkerRegistration.pushManager.getSubscription().then(subscription => {
      if (subscription) {
        subscription.unsubscribe().then((successful) => {
          if (successful) Discourse.ajax('/push_notifications/unsubscribe', {
            type: 'POST',
            data: { endpoint: endpointWorkaround(subscription) }
          });
        });
        if (callback) callback();
      }
    }).catch(e => Ember.Logger.error(e));
  });
}
