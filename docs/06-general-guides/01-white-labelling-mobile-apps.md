---
title: Things to consider before deciding to white-label the Discourse Mobile apps
short_title: White-labelling mobile apps
id: white-labelling-mobile-apps

---
Since we released the iOS and Android apps a number of people have asked expressed interest in white labeling the Discourse app. 

> :information_source:  We **do not** offer a white labeling service and would only consider it for enterprise customers as an added bundle. If this is something you're interested in, please discuss with us privately.

## Beware of the costs

White-labeling Discourse is a complex task and involves a significant amount of long term maintenance across Android and iOS. 

It is rare for it to be needed given Discourse has invested heavily in PWA support which allows you to have a shortcut on the home screen and push notifications on Android.

If you have a very large budget and **must** have your app searchable in various app stores or are looking to integrate into a larger mobile app this may be an approach you can take.

## Should you decide to proceed

If you decide to proceed with an effort to white label the apps on your own, please be aware of the following:

- Your apps **must not** be confused with the official Discourse apps. Avoid the word Discourse when white labeling. 

- The code for DiscourseMobile is open source and lives at: https://github.com/discourse/DiscourseMobile it is licensed under the very permissive MIT license

- Access to our "Push Notification" server is restricted to our customers. If you white-label you would need to setup Discourse to push notifications to a server of your choice using `allowed user api push urls` and implement a push notification receiver that re-publishes to Apple and Android play stores. 

We always welcome contributions to the Discourse app, if you have ideas and want to improve it and make it more white label friendly, let us know.
