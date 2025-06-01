---
title: Change icons globally
short_title: Global icon changes
id: global-icon-changes
---

This is an easy way to change a Discourse icon globally.

1. Right click on the icon you want to change and select "Inspect element" or "Inspect" (depends on the browser)

2. Find the icon name
   ![image|690x211,70%](/assets/global-icon-changes-1.png)
3. Search a new icon here https://fontawesome.com/icons?d=gallery, e.g. [external-link-alt](https://fontawesome.com/icons/external-link-alt?style=solid)

4. Customize and add the code in your `admin > customize > themes > edit code -> JS` tab

```gjs
// {theme}/javascripts/discourse/api-initializers/init-theme.gjs

import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.replaceIcon("link", "external-link-tab");
});
```

5. Icons that are not used by default from Discourse must be added in the site setting `svg icon subset` then force refresh your browser to see the changes applied.
   **Result:**
   ![image|277x64,60%](/assets/global-icon-changes-2.png)
   All the "link" icons will be replaced by "external-link-tab".
   If an icon is used for multiple elements in other pages, such as badges, the icon will also be replaced there.

---

## Exceptions

_Note that there is already a theme component that allow you to [change the Like icon](https://meta.discourse.org/t/change-the-like-icon/87748/1). I'm using this case as example_

The "heart" icon, used to give Like, is hardcoded with other names (`'d-liked'` and `'d-unliked'`) and should be treated differently than other icons, so to change the :heart: icon with :+1: icon:

```js
api.replaceIcon("d-liked", "thumbs-up");
api.replaceIcon("d-unliked", "thumbs-o-up");
```

![like|267x73,60%](/assets/global-icon-changes-3.png)
![firefox_2018-04-24_18-37-02|328x78,60%](/assets/global-icon-changes-4.png)
but on the badge page the icon is still "heart":
![firefox_2018-04-24_18-38-15|466x182,60%](/assets/global-icon-changes-5.png)
so to change it on that page we add:

```js
api.replaceIcon("heart", "thumbs-up");
```

![firefox_2018-04-24_18-47-50|457x172,60%](/assets/global-icon-changes-6.png)

Another example:

```js
api.replaceIcon("d-watching", "eye");
```

changes the watching icon:
![watching-original|166x356,60%](/assets/global-icon-changes-7.png) ![watching|189x365,60%](/assets/global-icon-changes-8.png)
[details="See here other exceptions that cover the tracking status, expand/collapse, notifications and likes of course."]

```js
const REPLACEMENTS = {
  "d-tracking": "bell",
  "d-muted": "discourse-bell-slash",
  "d-regular": "far-bell",
  "d-watching": "discourse-bell-exclamation",
  "d-watching-first": "discourse-bell-one",
  "d-drop-expanded": "caret-down",
  "d-drop-collapsed": "caret-right",
  "d-unliked": "far-heart",
  "d-liked": "heart",
  "d-post-share": "link",
  "d-topic-share": "link",
  "notification.mentioned": "at",
  "notification.group_mentioned": "users",
  "notification.quoted": "quote-right",
  "notification.replied": "reply",
  "notification.posted": "reply",
  "notification.edited": "pencil-alt",
  "notification.bookmark_reminder": "discourse-bookmark-clock",
  "notification.liked": "heart",
  "notification.liked_2": "heart",
  "notification.liked_many": "heart",
  "notification.liked_consolidated": "heart",
  "notification.private_message": "far-envelope",
  "notification.invited_to_private_message": "far-envelope",
  "notification.invited_to_topic": "hand-point-right",
  "notification.invitee_accepted": "user",
  "notification.moved_post": "sign-out-alt",
  "notification.linked": "link",
  "notification.granted_badge": "certificate",
  "notification.topic_reminder": "far-clock",
  "notification.watching_first_post": "discourse-bell-one",
  "notification.group_message_summary": "users",
  "notification.post_approved": "check",
  "notification.membership_request_accepted": "user-plus",
  "notification.membership_request_consolidated": "users",
  "notification.reaction": "bell",
  "notification.votes_released": "plus",
  "notification.chat_quoted": "quote-right",
};
```

Ref: [discourse/icon-library.js at main · discourse/discourse (github.com)](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/icon-library.js)
[/details]

---

Feel free to create other themes component and share it in our #theme-component category!
