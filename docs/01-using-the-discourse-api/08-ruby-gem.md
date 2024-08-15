---
title: Use the Discourse API ruby gem
short_title: Ruby gem
id: ruby-gem

---
<div data-theme-toc="true"> </div>

So you want to use [Discourse API](https://meta.discourse.org/t/discourse-api-documentation/22706)? Great! Let's get started.

## Set up Discourse development environment

Set up Discourse development environment using our [Windows](http://blog.discourse.org/2013/04/discourse-as-your-first-rails-app/), [OS X](https://meta.discourse.org/t/beginners-guide-to-install-discourse-on-mac-os-x-for-development/15772/) or [Ubuntu](https://meta.discourse.org/t/beginners-guide-to-install-discourse-on-ubuntu-for-development/14727/) guide.

## Clone Discourse API Gem

Now that you have set up Discourse development environment, you should already have Git and Ruby installed on your system. You can install Discourse API gem by running following command from console:

    git clone https://github.com/discourse/discourse_api.git ~/discourse_api

## Install dependencies

Open the `discourse_api` directory and type:

    bundle install

This will install any required gem dependencies.

## Generate Master API Key

Generate Master API Key for your Discourse instance by visiting `/admin/api`, to interact with Discourse API.

## Provide API Credentials

Now that you have cloned Discourse API gem and generated master API key, let's start using it!

Open the `discourse_api/examples/example.rb` file, and modify following information:

```
client = DiscourseApi::Client.new("http://localhost:3000")
client.api_key = "YOUR_API_KEY"
client.api_username = "YOUR_USERNAME"
```

Replace `http://localhost:3000` with the url of your discourse instance, eg: `http://discourse.example.com`

Replace `YOUR_API_KEY` with the master API key of your discourse instance, eg: `b1f3175cb682b3e9b6ca419db77772120b19af993cbc14ebed80fea08e3bbd66`

Replace `YOUR_USERNAME` with the Admin username of your discourse instance, eg: `codinghorror`

## Access Discourse API

Now in console, from `discourse_api` directory run:

    ruby examples/example.rb

This command will print out latest topics from your Discourse instance.

That's it. Start using [Discourse API](https://meta.discourse.org/t/discourse-api-documentation/22706) today.

--- 

*Additional Resources:* 
[ Discourse API Documentation](https://docs.discourse.org/#tag/Users/paths/~1admin~1users~1list~1%7Bflag%7D.json/get)


---
*Last Reviewed by @SaraDev on [date=2022-07-12 time=18:00:00 timezone="America/Los_Angeles"]*
