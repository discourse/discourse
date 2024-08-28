---
title: Discourse REST API comprehensive examples
short_title: API examples
id: api-examples

---
<div data-theme-toc="true"> </div>

There are [several guides](https://meta.discourse.org/search?q=%23rest-api%20%23documentation) covering various API uses or explanations.

This one gives practical and comprehensive examples on how to use it.

:warning: All code examples in this guide aren't meant to display good practice or to be used as they are.
A lot of checks, error handling and so on are purposely ignored or skipped to focus purely on the API's usage.

# What is the API used for?

Most of your actions in Discourse (posting, liking, editing a setting, etc.) are done using the API by making requests to an endpoint[^endpoint].

For example, when you create a topic on meta, a `POST` request is made to `https://meta.discourse.org/post.json`. The request contains, among other things, the author, title, category, tags and contents of your post.

Making custom use of the API is usually done to achieve automated tasks and often in conjunction with other services, like webhooks, scripts, third-party software and APIs.

[^endpoint]:  A particular URL, in this context. For example, `https://your-discourse.com/posts.json`

To use the API, it is mandatory to have API credentials. This can be done in a few clicks, by following this guide: https://meta.discourse.org/t/create-and-configure-an-api-key/230124?u=canapin

Wait no more, and let's go for a first example of an API use case. :technologist: 

# Creating a monthly topic

In this example, we'll use [curl](https://en.wikipedia.org/wiki/CURL) and [cron](https://en.wikipedia.org/wiki/Cron) to create a monthly "free talk" topic on your forum. A popular practice in online communities :)

## Create the API key

Go through the [API key creation guide](https://meta.discourse.org/t/create-and-configure-an-api-key/230124?u=canapin). Set **User Level** to Single User.
The chosen user will be the author of the monthly topic.
Then you can either go for a **Global** scop or a **Granular** scope, in which case it will need to have at least the **Topics** -> **write**" access.
Write down your generated API Key. :writing_hand: 

## Create a curl command

From your server's command line, run this command to see if it's working and if a topic is properly created using curl and Discourse's REST API with your API key:

```bash
curl -X POST "https://your-discourse.com/posts.json" -H "Content-Type: application/json" -H "Api-Key: YOUR_API_KEY" -H "Api-Username: YOUR_USERNAME" -d "{\"title\": \"Test topic creation with the API\", \"raw\": \"And here's the topic's content\", \"category\": CATEGORY_ID }"
```

Replace:
* `your-discourse.com` with your forum's domain
* `YOUR_API_KEY` with your API key
* `YOUR_USERNAME` with the API key's chosen username
* `CATEGORY_ID` with the ID of the category you want to post your topic in.

If everything's properly configured, a new test topic should be created on your forum, like:

![Test topic|690x221](/assets/api-examples-1.png)

Most of the work is done at this stage! We now need to change the topic's title and content for something more appropriate and set up the recurrence of the topic creation.

Start by changing the topic's title from:
`Test topic creation with the API`
to:
`Free talk of the month - $(date +\%B)`.

Let's do the same for the content from:
`Test topic creation with the API`
to:
`What have you appreciated the most and the less during $(date +\%B -d 'last month')?\nFeel free to share your feelings and provide ideas. 🙂`

:information_source: I'm using the [`date`](https://man7.org/linux/man-pages/man1/date.1.html) Unix command to insert the current month's name in the title and the previous month's name in the contents.

:information_source: `\n` in the contents creates a new line.

You can use the command line and run the updated curl request. It should have created a new topic like this on your forum:

![image|690x242](/assets/api-examples-2.png)

## Set up the recurring event

We'll create a cron task that will run the curl command on the first day of every month. :calendar: 

Edit the cron file with the following command:

```bash
crontab -e
```

Insert this line at the end of the file (replace the request's content as needed) and save the modification.
```bash
0 0 1 * * curl -X POST "https://your-discourse.com/posts.json" -H "Content-Type: application/json" -H "Api-Key: YOUR_API_KEY" -H "Api-Username: YOUR_USERNAME" -d "{\"title\": \"Free talk of the month - $(date +\%B)\", \"raw\": \"What have you appreciated the most and the less during $(date +\%B -d 'last month')?\nFeel free to share your feelings and provide ideas. 🙂\", \"category\": 4 }"
```

:information_source: The `0 0 1 * *` part defines the interval at which the command will run. You can learn more about the syntax here: https://crontab.guru

It's done! Your server will now create a new "free talk" topic the first day of each month, using Discourse's REST API, a curl request, and a cron task. :partying_face: 

# Automatically change the color scheme of a theme

Let's make our default theme use a color scheme matching the current season :snowflake: :hibiscus: :sunny: :fallen_leaf: 

We'll use Ruby to handle the months checks and a cron task to execute the script.

We could use many other ways than Ruby and cron, but this guide also aims to show how to use the API with various tools.

## Prepare the theme and color schemes

Choose the theme to which you want to change the color scheme of, and get its ID. you'll find the ID in the theme's URL. For instance, this theme's ID is 1:

![Theme's ID|649x500](/assets/api-examples-3.png)

Create 4 color palettes, and write down their ID as well.
Here, the Autumn's palette's ID is 17:

![Color scheme's ID|639x500](/assets/api-examples-4.png)

## Creating the script

[Install Ruby](https://www.ruby-lang.org/en/documentation/installation/) on your server.

Create a `seasons.rb` file. I'll consider it's in `~/scripts/` for this example.

Put the following content in this file. We'll make a POST request to our theme endpoint and send a payload containing the color scheme ID:

```rb
require 'net/http'
require 'json'
require 'date'

current_month = Date.today.month
color_scheme_id = case current_month
                  when 1..3 then 18 # Winter
                  when 4..6 then 15 # Spring
                  when 7..9 then 16 # Summer
                  else           17 # Autumn
                  end

uri = URI('https://your-discourse.com/admin/themes/THEME_ID.json')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Put.new(uri, {
  'Api-Key' => 'YOUR_API_KEY',
  'Api-Username' => 'YOUR_USERNAME',
  'Content-Type' => 'application/json'
})

request.body = JSON.generate({
  "theme" => {
    "color_scheme_id" => color_scheme_id
  }
})

response = http.request(request)
```

Replace:
* `your-discourse.com` with your forum's domain
* `YOUR_API_KEY` with your API key
* `YOUR_USERNAME` with the API key's chosen username
* `THEME_ID` with the ID of the Christmas theme component in your instance. You can find it at the end of the URL of the component's settings page.
For example, `https://your-discourse.com/admin/customize/themes/38`, the component's ID is `38`.

Let's manually try your script.
First, set it to a non-seasonal color scheme in Discourse's interface if it's not already the case.

Then, run the script with the following command:
```bash
ruby ~/scripts/seasons.rb
```
Refresh your browser. The color scheme used by your theme should have changed. :slight_smile: 

![Season color scheme change|video](upload://q3MMr0rXkyOxpViEZRgVYbgdL0G.mp4)

The last thing to do is create the cron job that will run this script on the first day of the month at each season change.

Have a look back at [the first example](https://meta.discourse.org/t/discourse-rest-api-comprehensive-examples/274354#set-up-the-recurring-event-5) if you don't remember how to create a cron task.

```bash
0 0 1 1,4,7,10 * ruby ~/scripts/seasons.rb
```

It's done! Your forum will now wear new colors at the beginning of each new season! :sunny: :partying_face: 

# Receive a web request on a web server and use its data to update a Discourse's topic

This one's more complex! :technologist: 

Our tool will be PHP, which means we'll assume you have a working web server somewhere with PHP installed.

In this example, we'll receive a [Ko-Fi](https://ko-fi.com/) (a donations service) webhook payload on a PHP page, which will then use the received data to use Discourse's API and update a topic's title and contents.

More specifically, it will update the topic's title with the donation amount and date, and add a new line to the table that lists previous donations (it will even automatically bump the topic :shushing_face:):

![Donations topic to update|690x417](/assets/api-examples-5.png)

Each time a user makes a donation, Ko-Fi[^ko-fi-api] will send a request to our PHP script.

[^ko-fi-api]: Bit of info about their API: https://help.ko-fi.com/hc/en-us/articles/360004162298-Does-Ko-fi-Have-an-API-or-Webhook-

## Configuring Ko-Fi

I set up the configuration on [Ko-Fi webhooks page](https://ko-fi.com/manage/webhooks) by simply adding my PHP file URL and writing down the verification token hidden in the Advanced section.

![image|690x385](/assets/api-examples-6.png)

On a single donation, Ko-Fi will send a payload like this to our PHP script:

```json
data = {
  "verification_token": "d8546b84-c698-4df5-9811-39d35813e2ff",
  "message_id": "a499df4c-7bbb-4061-b4a6-8b9d969da689",
  "timestamp": "2023-10-19T13:35:06Z",
  "type": "Donation",
  "is_public": true,
  "from_name": "Jo Example",
  "message": "Good luck with the integration!",
  "amount": "3.00",
  "url": "https://ko-fi.com/Home/CoffeeShop?txid=00000000-1111-2222-3333-444444444444",
  "email": "jo.example@example.com",
  "currency": "USD",
  "is_subscription_payment": false,
  "is_first_subscription_payment": false,
  "kofi_transaction_id": "00000000-1111-2222-3333-444444444444",
  "shop_items": null,
  "tier_name": null,
  "shipping": null
}
```
We'll receive this payload, then extract the two information we need:

* The **amount** (`3.00`), that we will round to an integer.

* The **timestamp** (`2023-10-19T13:35:06Z`), that we'll format into a more pretty date.

## Receive Ko-Fi's payload

First, we put the following code in our PHP page to receive the request from Ko-Fi, where we ensure that we received a POST request and that the token value matches the one given in the Ko-Fi webhooks page. We also format the amount and date as said earlier.

```php
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $jsonData = json_decode($_POST['data'], true);

    if ($jsonData['verification_token'] === 'YOUR_VERIFICATION_TOKEN') {
        $amount = floor(floatval($jsonData['amount']));
        $date = (new DateTime($jsonData['timestamp']))->format('d/m/Y');
    }
}
```
Replace:
* `YOUR_VERIFICATION_TOKEN` with the token given by Ko-Fi

## Update the topic's title

The next step is to update our topic's title. We'll use curl in our PHP script to make a PUT request to the proper endpoint.

```php
        $putData = json_encode(['title' => '🥳 New donation: ' . $amount . '€ on ' . $date]);
        $ch = curl_init('https://your-discourse.com/t/test-new-topic/TOPIC_ID');
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
        curl_setopt($ch, CURLOPT_POSTFIELDS, $putData);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Content-Length: ' . strlen($putData),
            'Api-Key: YOUR_API_KEY',
            'Api-Username: YOUR_USERNAME'
        ]);
        curl_exec($ch);
```
Replace:
* `your-discourse.com` with your forum's domain
* `TOPIC_ID` with the right topic's ID
* `YOUR_API_KEY` with your API key
* `YOUR_USERNAME` with the API key's chosen username

## Update the post's content

To be able to append new content to the topic's first post, we need first to retrieve its current content with a GET request.

```php
        $ch_get = curl_init('https://your-discourse.com/posts/POST_ID.json');
        curl_setopt($ch_get, CURLOPT_RETURNTRANSFER, true);
        $currentContent = json_decode(curl_exec($ch_get), true)['raw'];
```
Replace:
* `POST_ID` with the right post's ID[^post-id]

[^post-id]: The post ID can be found in the HTML code. It's an `<article>` element with the following attribute: `data-post-id="POST_ID"`

Finally, we need to update the post content by adding a new line to the table with the amount and date. We'll do that with a PUT request.
```php
        $updatedContent = $currentContent . "\n| " . $amount . "€ | " . $date . " |";
        $putPostData = json_encode(['post' => ['raw' => $updatedContent]]);
        $ch_put = curl_init('https://your-discourse.com/posts/POST_ID');
        curl_setopt($ch_put, CURLOPT_CUSTOMREQUEST, 'PUT');
        curl_setopt($ch_put, CURLOPT_POSTFIELDS, $putPostData);
        curl_setopt($ch_put, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Content-Length: ' . strlen($putPostData),
            'Api-Key: YOUR_API_KEY',
            'Api-Username: YOUR_USERNAME'
        ]);
        curl_exec($ch_put);
```
Replace:
* `your-discourse.com` with your forum's domain
* `POST_ID` with the right post's ID
* `YOUR_API_KEY` with your API key
* `YOUR_USERNAME` with the API key's chosen username

The final code looks like this:

```php
<?php
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $jsonData = json_decode($_POST['data'], true);

    if ($jsonData['verification_token'] === 'YOUR_VERIFICATION_TOKEN') {
        $amount = floor(floatval($jsonData['amount']));
        $date = (new DateTime($jsonData['timestamp']))->format('d/m/Y');

        $putData = json_encode(['title' => '🥳 New donation: ' . $amount . '€ on ' . $date]);
        $ch = curl_init('https://your-discourse.com/t/test-new-topic/TOPIC_ID');
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
        curl_setopt($ch, CURLOPT_POSTFIELDS, $putData);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Content-Length: ' . strlen($putData),
            'Api-Key: YOUR_API_KEY',
            'Api-Username: YOUR_USERNAME'
        ]);
        curl_exec($ch);

        $ch_get = curl_init('https://your-discourse.com/posts/POST_ID.json');
        curl_setopt($ch_get, CURLOPT_RETURNTRANSFER, true);
        $currentContent = json_decode(curl_exec($ch_get), true)['raw'];

        $updatedContent = $currentContent . "\n| " . $amount . "€ | " . $date . " |";
        $putPostData = json_encode(['post' => ['raw' => $updatedContent]]);
        $ch_put = curl_init('your-discourse.com/posts/POST_ID');
        curl_setopt($ch_put, CURLOPT_CUSTOMREQUEST, 'PUT');
        curl_setopt($ch_put, CURLOPT_POSTFIELDS, $putPostData);
        curl_setopt($ch_put, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'Content-Length: ' . strlen($putPostData),
            'Api-Key: YOUR_API_KEY',
            'Api-Username: YOUR_USERNAME'
        ]);
        curl_exec($ch_put);

        curl_close($ch);
        curl_close($ch_get);
        curl_close($ch_put);
    } else {
        http_response_code(403);
        echo "Invalid verification token.";
    }
} else {
    http_response_code(405);
    echo "Only POST requests are allowed.";
}
?>
```

Let me emphasize again the warning at the beginning of this guide :stuck_out_tongue: 

> :warning: All code examples in this guide aren't meant to display good practice or to be used as they are.
> A lot of checks, error handling and so on are purposely ignored or skipped to focus purely on the API's usage.

We can now trigger a test request from Ko-Fi, and see how it updates our topic, both the title and content. :slight_smile:

That's all !
You have a topic that will be updated and bumped each time someone makes a donation on Ko-Fi! :partying_face: 

---

:information_source: This topic is a wiki. Please feel free to correct any error you see and to discuss how this guide could be improved.
