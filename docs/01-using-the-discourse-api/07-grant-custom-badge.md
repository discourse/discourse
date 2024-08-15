---
title: Grant a custom badge through the API
short_title: Grant custom badge
id: grant-custom-badge

---
Custom badges that you have created on your forum can be granted through the API. This is a great way to award badges without having to use custom badge SQL.

To grant a badge through the API, you need to know the username of the user that you wish to grant the badge to, and the ID of the badge you wish to grant. You also need to make sure you have generated an All Users API Key from your site's Admin/API section.

### Finding your API Key

This screenshot is from my local development site. Generally, you need to be very careful about sharing your API keys:

![45%20AM|690x122](/assets/grant-custom-badge-1.png) 

### Finding the Badge ID

You can get the Badge ID from the badge's URL. Go to your Admin/Badges section and then click on the badge that you wish to grant. The URL will look something like this: `https://forum.example.com/admin/badges/102`. The last number in the URL is the badge ID.

### Making the API call

To test an API call, you can try granting a badge using curl or [Postman](https://www.getpostman.com/). Here is how I grant a badge from my computer's terminal with curl.

First, to make things easier, set an `api_key` variable:

```text
 api_key=yourallusersapikey
```

Then to grant a badge with the ID of 102 to the user `bobby`:

```
curl -X POST "https://forum.example.com/user_badges" \
-H "Content-Type: multipart/form-data;" \
-H "Api-Key: $api_key" \
-H "Api-Username: system" \
-F "username=bobby" \
-F "badge_id=102" \
-F "reason=https://forum.example.com/t/whats-the-best-photo-youve-ever-taken/160/2"
```

The `reason` parameter is optional. If you supply it, it must be set to the URL of a topic or a post on your site.

You should get a JSON response with details about the badge and when it was granted.
