---
title: "Theme Developer Tutorial: 4. Using Outlets to insert and replace content"
short_title: 4 - Outlets
id: theme-developer-tutorial-outlets
---

Discourse uses the [Ember JS Framework](https://emberjs.com/) for its user interface. On top of Ember, Discourse provides a number of APIs to allow themes to customize the user interface. The most commonly-used API is Plugin Outlets.

These outlets are positioned throughout Discourse core, and allow themes to render Ember Components inside them. Those components are given access to some contextual information called "outlet args".

Some outlets also "wrap" part of the core user interface, which allows themes to add their own wrapper HTML around that part of core, or even replace it entirely! These are called "Wrapper Outlets".

## Choosing an outlet

In the earlier chapter of this tutorial, you used `api.renderInOutlet` to render a component into the `discovery-list-container-top` outlet. But how do we know what outlets are available, where they're located, and what outlet args are available?

Enter: the discourse developer toolbar. If you're running Discourse in a local development environment, you may have spotted this floating on the left-hand side of the screen. If you're developing a theme against a production Discourse environment, open the browser developer console and run `enableDevTools()` to make it appear.

To see the location of all outlets on the current page, click the 🔌 icon in the developer toolbar. You should now see a bunch of green & blue placeholders throughout the application. Green placeholders are for simple outlets where you can render new content. Blue placeholders appear at the beginning and end of each "wrapper outlet".

When you mouseover an outlet, a tooltip will show the available `outletArgs`, and a button to write each argument to the browser developer console to explore in more detail.

## Rendering a simple component

Let's explore the `renderInOutlet` API in more detail.

```js
api.renderInOutlet(outletName, component);
```

The first argument is a string representing the name of the outlet you want to target. The second argument is an Ember Component class. Ember provides a few different options for authoring components, but for new developments in Discourse we recommend "Glimmer Components", authored using the "template tag" format (i.e. `.gjs` files).

The simplest component is a "template only component", and can be authored like this:

```gjs
const MyComponent = <template>Hello World</template>;
api.renderInOutlet("some-outlet", MyComponent);

// Or on one line
api.renderInOutlet("some-outlet", <template>Hello World</template>);
```

Inside the `<template>` you can use handlebars syntax to render simple HTML, dynamic content, and other components. We'll cover a few things here, but [The Ember Guides](https://guides.emberjs.com/release/components/) are the best place to learn more about the syntax and everything that's possible.

To access JavaScript variables from inside the template, you can wrap your variable name in double curly brackets. That's the technique we used in the earlier chapters:

```gjs
const currentUser = api.getCurrentUser();

api.renderInOutlet(
  "discovery-list-container-top",
  <template>
    <div class="custom-welcome-banner">
      {{#if currentUser}}
        Welcome back @{{currentUser.username}}
      {{else}}
        Welcome to our community
      {{/if}}
    </div>
  </template>
);
```

To access contextual arguments passed to Ember Components, you can use the syntax `{{@someArgument}}`. In the case of outlets, all the contextual "outlet arguments" are made available via the `@outletArgs` object.

If you use the developer tools to find the `discovery-list-container-top` outlet, you'll see there are two contextual `outletArgs` available: `category` and `tag`. Let's use the category information to add the category name to our welcome banner:

```gjs
api.renderInOutlet(
  "discovery-list-container-top",
  <template>
    <div class="custom-welcome-banner">
      {{#if currentUser}}
        Welcome back @{{currentUser.username}}.
      {{else}}
        Welcome to our community.
      {{/if}}
      You're viewing
      {{#if @outletArgs.category}}
        "{{@outletArgs.category.name}}" topics.
      {{else}}
        all topics.
      {{/if}}
    </div>
  </template>
);
```

Save that change, and check the preview in your browser. When you navigate between categories, the banner will update accordingly.

This is a great example of Ember's "autotracking" system. All we have to do is reference the `.category` property, and Ember will automatically take care of re-rendering that part of the HTML whenever the property changes. Magic!

## Class-based Components

For more advanced use-cases, we need a place to store state and JS logic inside a component definition. That can be done using a class-based Glimmer Component. Class based components can also inject application-wide Services to get global information like `currentUser`. A class-based version of our welcome banner would look like:

```gjs
import Component from "@glimmer/component";
import { service } from "@ember/service";

class CustomWelcomeBanner extends Component {
  @service currentUser;

  <template>
    <div class="custom-welcome-banner">
      {{#if this.currentUser}}
        Welcome back @{{this.currentUser.username}}.
      {{else}}
        Welcome to our community.
      {{/if}}
    </div>
  </template>
}
```

You can put this code anywhere that you can access from the initializer. That could mean simply adding it to the top of the file. But in general, once you reach the complexity of a class-based component, it's best to put it in its own file, export it, and then import from the initializer.

So, let's go ahead and create a new file: `javascripts/discourse/components/custom-welcome-banner.gjs`, and include this new component as the default export:

```gjs
import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class CustomWelcomeBanner extends Component {
  @service currentUser;

  <template>
    <div class="custom-welcome-banner">
      {{#if this.currentUser}}
        Welcome back @{{this.currentUser.username}}.
      {{else}}
        Welcome to our community.
      {{/if}}
    </div>
  </template>
}
```

Then, back in the initializer, we can import it using a "relative import" at the top of the file, and then pass it through to the `renderInOutlet` function. The entire initializer should now look like:

```gjs
import { apiInitializer } from "discourse/lib/api";
import CustomWelcomeBanner from "../components/custom-welcome-banner";

export default apiInitializer((api) => {
  api.renderInOutlet("discovery-list-container-top", CustomWelcomeBanner);
});
```

## Wrapper Outlets

We won't explore them in this tutorial, but Wrapper Outlets work almost exactly the same as normal outlets. The only difference is that your component will replace any core content inside the wrapper. For example, rendering into the "home-logo-contents" outlet would replace the site logo with your own component.

If you want to re-render the wrapped core implementation inside your component, you can use Ember's `{{yield}}` keyword.

## Conclusion

Now we know how to create and insert content across the whole of Discourse, we'll explore some more advanced concepts you can use in your components. See [the next chapter](https://meta.discourse.org/t/357800)
