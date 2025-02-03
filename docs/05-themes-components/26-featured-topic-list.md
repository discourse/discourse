---
title: Add a featured topic list to your Discourse homepage
short_title: Featured topic list
id: featured-topic-list
---

In this #howto we'll add a topic list populated by a tag or a category on top of your homepage's main topic list, like this:

![04%20PM|690x342](/assets/featured-topic-list-1.png)

All of the code below can be added to the `</head> (head_tag.html)` section of your theme.

This first part checks which page we're on, then sets up our topics. For the purpose of this how-to we're pulling topics tagged `featured`. If you want to pull topics from another tag or a category you need to change the `/tags/featured.json` url in here.

```html
<script type="text/discourse-plugin" version="0.8">
  const ajax = require('discourse/lib/ajax').ajax;
  const Topic = require('discourse/models/topic').default;
  // We're using ajax and the Topic model from Discourse

  api.registerConnectorClass('above-main-container', 'featured-topics', {
    // above-main-container is the plugin outlet,
    // featured-topics is your custom component name

    setupComponent(args, component) {

      api.onPageChange((url, title) => {
        if ((url == "/") || (url == "/latest") ){
        // on page change, check if url matches
        // if your homepage isn't /latest change this to /categories

          $('html').addClass('custom-featured-topics');
          // add a class to the HTML tag for easy CSS targetting

          component.set('displayFeaturedTopics', true);
          // we'll use this later to show our template

          component.set("loadingTopics", true);
          // helps us show a loading spinner until topics are ready

          ajax("/tag/featured.json").then (function(result){
          // Get posts from tag "featured" using AJAX
          // if this were a category you'd use /c/featured.json

            let featuredTopics = [];
            // Create an empty array, we'll push topics into it

            var featuredUsers = result.users;
            // Get the relevant users

            result.topic_list.topics.slice(0,4).forEach(function(topic){
              // We're extracting the topics starting at 0 and ending at 4
              // This means we'll show 3 total. Increase 4 to see more.

              topic.posters.forEach(function(poster){
                // Associate users with our topic
                poster.user = $.grep(featuredUsers, function(e){ return e.id == poster.user_id; })[0];
              });

              featuredTopics.push(Topic.create(topic));
              // Push our topics into the featuredTopics array
            });

            component.set("loadingTopics", false);
            // Topics are loaded, stop showing the loading spinner

            component.set('featuredTopics', featuredTopics);
            // Setup our component with the topics from the array
          });
        } else {
          // If the page doesn't match the urls above, do this:

          $('html').removeClass('custom-featured-topics');
          // Remove our custom class

          component.set('displayFeaturedTopics', false);
          // Don't display our customization
        }
      });
    }
  });
</script>
```

This second part is your handlebars template. This is your HTML. Note how the script tag references the relevant plugin outlet and the custom component name set above.

```html
<script
  type="text/x-handlebars"
  data-template-name="/connectors/above-main-container/featured-topics"
>
  {{#if displayFeaturedTopics}}
    <!-- If our component is true, show this content: -->
    <div class="custom-featured-topics-wrapper">
      {{conditional-loading-spinner condition=loadingTopics}}
      <!-- Show a loading spinner if topics are loading -->

      {{#unless loadingTopics}}
        <!-- Unless topics are still loading... -->
        {{topic-list topics=featuredTopics showPosters=true}}
        <!-- Show the topic list -->
      {{/unless}}
    </div>
  {{/if}}
</script>
```

Now you'll have a featured topic list on your homepage.

If you want to add custom CSS (`common.scss`) for some additional styling, you'd do it like this:

```scss
.custom-featured-topics {
  .custom-featured-topics-wrapper .topic-list {
    // your css here, at minimum you'll probably want some margin:
    margin-bottom: 2em;
  }
}
```

If you want to learn more about the topics covered in this example or see what else you can do with the Plugin API, check out our [Developer’s guide to Discourse Themes](https://meta.discourse.org/t/developer-s-guide-to-discourse-themes/93648)
