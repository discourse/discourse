---
title: Run Data Explorer queries with the Discourse API
short_title: Data &#8204;Explorer queries # nonbreaking-space to avoid autolinking 🤦‍♂️
id: data-explorer-queries

---
<div data-theme-toc="true"> </div>

Virtually any action that can be performed through the Discourse user interface can also be triggered with the Discourse API. For a general overview of how to find the correct API request for an action, see https://meta.discourse.org/t/how-to-reverse-engineer-the-discourse-api/20576.

To run a Data Explorer query from the API, you need to make a `POST` request to `/admin/plugins/explorer/queries/<query-id>/run`. You can find the a Data Explorer query's ID by visiting the query on your site and getting the value of the `id` parameter that you'll see in your browser's address bar.

This example query has an ID of `20` on my site. It returns a list of topics, ordered by views, for a given date:

``` sql
--[params]
-- date :viewed_at

SELECT
topic_id,
COUNT(1) AS views_for_date
FROM topic_views
WHERE viewed_at = :viewed_at
GROUP BY topic_id
ORDER BY views_for_date DESC
```

This query can be run from a terminal with:

``` text
curl -X	POST "https://discourse.example.com/admin/plugins/explorer/queries/20/run" \
-H "Content-Type: multipart/form-data;" \
-H "Api-Key: <your_all_users_api_key>" \
-H "Api-Username: system" \
-F 'params={"viewed_at":"2019-06-10"}'
```

You will need to substitute your site's base URL, query ID, and All Users API key into the example.

### Handling queries that return over 1000 rows

> :warning: The `limit=ALL` support for CSV exports has been removed, but should still work for JSON exports.  

By default, the Data Explorer plugin returns a maximum of 1000 rows. [s]You can bypass this limit by adding a `limit=ALL` parameter to the request.[/s] The query below will generate 10000 rows.

``` sql
SELECT
*
FROM generate_series(1, 10000)
```

On my site, the query's ID is `26`. Here's how to get all the query's rows:

```
curl -X POST "https://discourse.example.com/admin/plugins/explorer/queries/26/run" \
-H "Content-Type: multipart/form-data;" \
-H "Api-Key: <your_all_users_api_key>" \
-H "Api-Username: system" \
-F "limit=ALL"
```

### Paginating the results

For a query that returns a very large data set, you can paginate the results. Given this example query (it has an `id` of 27 on my site):

``` sql
--[params]
-- integer :limit = 100
-- integer :page = 0

SELECT
*
FROM generate_series(1, 10000)
OFFSET :page * :limit
LIMIT :limit
```

you can return the first 100 rows with

```
curl -X POST "https://discourse.example.com/admin/plugins/explorer/queries/27/run" \
-H "Content-Type: multipart/form-data;" \
-H "Api-Key: <your_all_users_api_key>" \
-H "Api-Username: system" \
-F 'params={"page":"0"}'
```
You can keep incrementing the value of the `page` parameter until the `result_count` that is returned is `0`.

### Removing `relations` data from the results

When Data Explorer queries are run through the user interface, a `relations` object is added to the results. This data is used for rendering the user in UI results, but you are unlikely to need it when running queries via the API. To remove that data from the results, pass a `download=true` parameter with your request:

```
curl -X POST "https://discourse.example.com/admin/plugins/explorer/queries/27/run" \
-H "Content-Type: multipart/form-data;" \
-H "Api-Key: <your_all_users_api_key>" \
-H "Api-Username: system" \
-F 'params={"page":"0"}' \
-F "download=true"
```

### API authentication

Details about generating an API key for the requests can be found here: https://meta.discourse.org/t/create-and-configure-an-api-key/230124. If the API key is only going to be used to run Data Explorer queries, select "Granular" from the Scope drop down, then select the "run queries" scope.

![Screenshot 2024-04-12 at 3.11.52 PM|690x104, 75%](/assets/data-8204-explorer-queries-1.png)

### Common Questions

> *Is there any api endpoint I can use to get the list of reports and the ID numbers? I want to build a dropdown with the list in it?* 

Yes, you can make an authenticated GET request to `/admin/plugins/explorer/queries.json` to get a list of all queries on the site.


> *Is it possible to send parameters with the post request?*

Yes, the first code example in the OP should give you what you are looking for. It passes a `viewed_at` parameter, but a similar approach would work with a `category_id` parameter.

### Additional Resources

[quote="Lee Dohm, post:44, topic:120063, full:true, username:lee-dohm"]
My team has reports that we run weekly for internal meetings, checkins, and such. In the interest of “automating all the things” I created a [GitHub Action ](https://github.com/features/actions) to allow for [easy execution of Data Explorer queries ](https://github.com/lee-dohm/execute-discourse-query). This allows me to create workflows that run these queries on a periodic basis and open GitHub Issues with the results.

I don’t know if it would be helpful for anyone else but I wanted to offer it as an option for people if it would be useful.
[/quote]
