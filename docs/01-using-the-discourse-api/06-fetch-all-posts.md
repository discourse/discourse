---
title: Fetch All Posts from a Topic Using the API
short_title: Fetch all posts
id: fetch-all-posts

---
> :notebook_with_decorative_cover: This is a how-to guide explaining how to fetch all posts from a topic using the Discourse API

The results returned by the Discourse API for many routes are paginated. 

For example, the API endpoint for ["Get A Single Topic"](https://docs.discourse.org/#tag/Topics/operation/getTopic) - Ex: `https://examplesite/t/{id}.json` will only return 20 posts by default, even if the topic contains more than 20 posts. 

Due to this behavior, there are two ways you can use the Discourse API to fetch all posts for a topic using the `.../t/{id}.json` endpoint. 

# Append a Query Parameter

The easiest way fetch all posts from a topic is to add a `print=true` query parameter to the URL you are making the request to. 

Ex: `https://examplesite/t/{id}.json?print=true`

When the `print=true` query parameter is added, Discourse sets the `chunk_size` for the number of posts that are returned to 1000. That means that this is a good approach to use as long as you are certain that your topics have no more than 1000 posts.

# Multiple API Requests
The other method for fetching all posts is to make multiple API requests to get all of the posts from the topic: 

1. First, you would make an initial `GET` request to the `.../t/{id}.json` endpoint. This will contain a `posts_stream` hash that contains a `posts` array and a `stream` array. The `posts` array will give you the first 20 posts.

2. Now you need to loop through the `stream` array which gives you all of the post ids in the topic. Remove the first 20 post ids from the stream (otherwise you are re-downloading them for no reason).

3. You can then make additional requests to the ["Get Specific Posts From a Topic"](https://docs.discourse.org/#tag/Topics/operation/getSpecificPostsFromTopic) `.../t/{id}/posts.json` endpoint, append `post_ids[]`, and pass in all the ids from the `stream` array in chunks of 20. Ex `
.../t/{id}/posts.json?post_ids[]=46&post_ids[]=47&post_ids[]=48&post_ids[]=49&post_ids[]=50&post_ids[]=51&post_ids[]=52&post_ids[]=53&post_ids[]=54&post_ids[]=55&post_ids[]=56&post_ids[]=57&post_ids[]=58&post_ids[]=59&post_ids[]=60&post_ids[]=61&post_ids[]=62&post_ids[]=63&post_ids[]=64&post_ids[]=65`

# Rate Limits

If you encounter an `Error: you have performed this action many times, please try again later` message when making multiple API calls this indicates that you are running into API key rate limits.

Discourse has a limit on the number of `print=true` requests that can be made per hour, which is controlled by the `max prints per hour per user` site setting. This setting defaults to only allow users to print 5 topics per hour. You can set that setting to `0` to disable the rate limit.

![image|690x105](/assets/fetch-all-posts-1.png)

Note that the rate limit will not be applied if you use an All Users API key for the requests and supply the username of a site admin for the request’s `Api-Username` parameter. That means that instead of disabling the `max prints per hour per user` site setting, you could just use an admin username (for example `system` ) for the requests.

If you are running into rate limit errors with API requests that do not contain `print=true`, we recommend adding a timeout to your API script so that you don’t exceed the rate limits. Alternatively, you can listen for `429` (too many requests) error codes and backoff on the requests when you receive that response.

For reference, the default rate limits listed below apply to our standard and business hosted plans: 

https://github.com/discourse/discourse/blob/main/config/discourse_defaults.conf#L235-L242

> :grey_exclamation: *Self Hosted Only* - See: https://meta.discourse.org/t/available-settings-for-global-rate-limits-and-throttling/78612 for details about adjusting Discourse API rate limits.
