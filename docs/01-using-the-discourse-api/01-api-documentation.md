---
title: Discourse REST API Documentation
short_title: API documentation
id: api-documentation

---
<div data-theme-toc="true"> </div>

# Discourse API


Please view the Discourse API Documentation site for detailed info:

  https://docs.discourse.org

> ## :warning: Deprecation Warning!
> **On April 6th, 2020 we dropped support for all non-HTTP header based authentication (excluding some rss, mail-receiver, and ics routes).** This means that API requests that have an `api_key` and `api_username` in the query params or in the HTTP body of the request will soon stop working. Please see the example cURL request below for how to update your API requests to use the HTTP headers for authentication.

[details="Additional Deprecation Details"]
> During November 2019 we released an update to your admin dashboard that would appear if it detected this deprecated API authentication method. Please check your admin dashboard for this message and make the appropriate changes to any API integrations you may have. If you do not see this message you either have an API integration that triggers less than once every 24 hours or you don’t have any affected API integrations and have nothing to update.
>
> We are making this change in an effort to further increase the security of all Discourse sites by removing the support of API authentication credentials inside of query parameters and requiring that authentication credentials are passed inside of HTTP Headers. 
>
>The only API endpoints that will not be affected and will continue to have support for credentials in query parameters will be requests to RSS feeds and the Mail Receiver endpoint.
>
> For the deprecated API request message, you can check your API keys in your admin dashboard `/admin/api/keys` to see when they were last used.
>
> The changelog can be found here: [https://github.com/discourse/discourse_api/blob/master/CHANGELOG.md ](https://github.com/discourse/discourse_api/blob/master/CHANGELOG.md)
[/details]


The Content-Type can be set to "application/x-www-form-urlencoded",  "multipart/form-data" or "application/json".

Here is an example POST request via cURL:

```text
curl -X POST "http://127.0.0.1:3000/categories" \
-H "Content-Type: multipart/form-data;" \
-H "Api-Key: 714552c6148e1617aeab526d0606184b94a80ec048fc09894ff1a72b740c5f19" \
-H "Api-Username: discourse1" \
-F "name=89853c20-4409-e91a-a8ea-f6cdff96aaaa" \
-F "color=49d9e9" \
-F "text_color=f0fcfd"
```

<hr>

Here is an example of what the [API Documentation site](http://docs.discourse.org) looks like:

![redoc](/assets/api-documentation-1.gif)

## Consuming the API

You can consume the API using cURL commands, but we recommend using the [discourse_api](http://github.com/discourse/discourse_api) gem so that you can use Ruby.

https://meta.discourse.org/t/using-the-discourse-api-ruby-gem/17587

## Reverse engineering API endpoints

Not every endpoint is documented, but you can see an example API request and response for any endpoint by follow this guide:

https://meta.discourse.org/t/how-to-reverse-engineer-the-discourse-api/20576

## Global rate limits and throttling in Discourse
Discourse ships with 3 different global rate limits that can be configured by site admins. For more details about these limits see: 
https://meta.discourse.org/t/global-rate-limits-and-throttling-in-discourse/78612

## Creating notifications via the API

https://meta.discourse.org/t/creating-notifications-via-the-api/173769

## User API keys specification 

https://meta.discourse.org/t/user-api-keys-specification/48536

---
*Last Reviewed by @SaraDev on [date=2022-06-03 time=10:00:00 timezone="America/Los_Angeles"]*
