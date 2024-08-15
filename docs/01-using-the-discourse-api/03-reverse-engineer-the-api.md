---
title: Reverse engineer the Discourse API
short_title: Reverse engineer the API
id: reverse-engineer-the-api

---
Discourse is backed by a complete JSON api. Anything you can do on the site you can also do using the JSON api. 

Many of the endpoints are properly documented in the [discourse_api][1] gem, however some endpoints lack documentation. 

To determine how to do something with the JSON API here are some steps you can follow. 

### Example: recategorize a topic.

- Go to a topic and start editing a category:

![image|526x151](/assets/reverse-engineer-the-api-1.png)

- Open Chrome dev tools, switch to the Network tab, select XHR filter:

![image|513x500](/assets/reverse-engineer-the-api-2.png)

- Perform the operation

![image|690x469](/assets/reverse-engineer-the-api-3.png)

- Note that in some versions of Chrome, the "Form Data" will be located under the "Payload" tab

![image|690x47, 75%](/assets/reverse-engineer-the-api-4.png)

- Look at preview as well to figure out the results

<img src="//assets-meta-cdck-prod-meta.s3.dualstack.us-west-1.amazonaws.com/original/3X/a/f/af1560423c5cbee00f1f5fe4685d7b798c52494f.png" width="687" height="178">

- You now have all the info you need. 

 1. The endpoint is `http://try.discourse.org/t/online-learning/108.json`

 2. Payload is passed using a `PUT`

 3. The parameter sent is: `category_id: 5`

Equipped with this information you can make your own calls using your favorite programming language. All you need to do is add your  `Api-Username` and `Api-Key` to the request headers. (See https://meta.discourse.org/t/discourse-api-documentation/22706 for details about how to formulate a curl request to the Discourse API.)

API credentials can be generated from the Admin / API tab:

![image|690x180](/assets/reverse-engineer-the-api-5.png)

[1]: https://github.com/discourse/discourse_api

---
*Last Reviewed by @SaraDev on [date=2022-06-02 time=17:00:00 timezone="America/Los_Angeles"]*
