'use strict';

function showNotification(title, body, icon, tag,url) {
  var notificationOptions = {
    body: body,
    icon: icon,
    data: { url: url },
    tag: tag
  }

  self.registration.showNotification(title, notificationOptions);
}

self.addEventListener('push', function(event) {
  event.waitUntil(
    fetch("/push_notifications/latest.json", { credentials: 'same-origin', mode: 'same-origin' }).then(function(response) {
      if (response.status !== 200) {
        console.error('There was an error fetching the notifications. Status code: ' + response.status);
        throw new Error();
      }

      response.json().then(function(data) {
        var tag = data.tag;

        self.registration.getNotifications({ tag: tag }).then(function(notifications) {
          if (notifications && notifications.length > 0) {
            notifications.forEach(function(notification) {
              notification.close();
            });
          }

          showNotification(data.title, data.body, data.icon, tag, data.url)
        });
      });
    }).catch(function(error) {
      console.error('There was an error retrieving the notifications', error);
    })
  );
});

self.addEventListener('notificationclick', function(event) {
  // Android doesn't close the notification when you click on it
  // See: http://crbug.com/463146
  event.notification.close();
  var url = event.notification.data.url;

  // This looks to see if the current window is already open and
  // focuses if it is
  event.waitUntil(
    clients.matchAll({ type: "window" })
      .then(function(clientList) {
        clientList.forEach(function(client) {
          if (client.url === url && 'focus' in client) return client.focus();
        });

        if (clients.openWindow) return clients.openWindow(url);
      })
  );
});
