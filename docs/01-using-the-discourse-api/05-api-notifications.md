---
title: Get notifications via the API
short_title: API notifications
id: api-notifications

---
If you have an existing website or application and you would like to encourage discussion on your Discourse forum it can be helpful to display Discourse notifications inside of your application. This guide will show you how to use the Discourse API to fetch notifications for a user and how to mark them as read.

The recommended way of using the API is to have your application make back-end requests to Discourse and then pass that data to the front-end/presentation layer of your application.

Checkout the [API Documentation](https://meta.discourse.org/t/discourse-api-documentation/22706) for info on how to use the Discourse API.

## Fetching notifications for a user

To get notifications via the API you can make an authenticated GET request to the `/notifications` endpoint. You can either specify the username you are fetching notifications for in the Api-Username header or as a query parameter: `/notifications?username=<username>`.

### Example request

``` text
curl -X GET "http://localhost:8080/notifications.json?username=blake.erickson" \ 
-H "Api-Key: e81c4022f148c872a98fb38dac1d9619c7f5b245b42ba98fa467968bbed7551e" \ 
-H "Api-Username: system"
```

This will return the following the JSON response

``` json
{
  "notifications": [
    {
      "id": 3,
      "notification_type": 12,
      "read": true,
      "created_at": "2019-06-17T20:26:05.670Z",
      "post_number": null,
      "topic_id": null,
      "slug": null,
      "data": {
        "badge_id": 41,
        "badge_name": "First Emoji",
        "badge_slug": "first-emoji",
        "badge_title": false,
        "username": "blake"
      }
    },
    {
      "id": 2,
      "notification_type": 6,
      "read": true,
      "created_at": "2019-06-17T20:26:04.305Z",
      "post_number": 1,
      "topic_id": 10,
      "fancy_title": "Greetings!",
      "slug": "greetings",
      "data": {
        "topic_title": "Greetings!",
        "original_post_id": 14,
        "original_post_type": 1,
        "original_username": "discobot",
        "revision_number": null,
        "display_username": "discobot"
      }
    }
  ],
  "total_rows_notifications": 2,
  "seen_notification_id": 3,
  "load_more_notifications": "/notifications?offset=60&username=blake"
}
```

This returns a notification array. If you are interesting in only showing unread notifications you will need to only grab notifications marked as `"read": false` from the array.

You can visit this page for a listing of [notification types](https://github.com/discourse/discourse/blob/master/app/models/notification.rb#L46-L69). For example notification type: 12 maps to "granted_badge".

## Marking notifications as read

Now that you have fetched a user's notifications you can mark them as read by sending a PUT request to `/notifications/mark-read` with the `id` of the notification in the request body and by specifying the username in the request header.

### Example request

``` text
curl -X PUT "http://localhost:8080/notifications/mark-read" \ 
-H "Api-Key: e81c4022f148c872a98fb38dac1d9619c7f5b245b42ba98fa467968bbed7551e" \
-H "Api-Username: blake.erickson" \
-F "id=4"
```

You can also leave off the notification id and it will mark all notifications for that user as read.

This will return a simple "OK" JSON response:

``` json
{
  "success": "OK"
}
```
