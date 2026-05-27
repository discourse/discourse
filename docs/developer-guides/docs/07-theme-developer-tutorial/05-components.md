---
title: "Theme Developer Tutorial: 5. Building and using components"
short_title: 5 - Components
id: theme-developer-tutorial-components
---

In the last chapter, we explored how you can render Glimmer Components into plugin outlets, and moved our `CustomWelcomeBanner` component into its own file. In this chapter, we'll extend the functionality of the banner to demonstrate some more techniques for authoring components, including re-using other components from Discourse Core.

## Adding JS logic

In previous chapters, we've used variables and `if` statements to render dynamic content in handlebars templates. For more complex logic, we can use regular JavaScript and then reference it from the template.

Taking our existing `CustomWelcomeBanner` component, we can learn more about the `currentUser` object by adding `{{log this.currentUser}}` into the template. Then check your browser developer console to explore the object. You'll see a "groups" key available, which lists all the groups the user is part of.

Let's display a list of the groups in the welcome banner. While it's technically possible to do that entirely in handlebars, it'll be much easier to do it in JavaScript. So, let's create a JS getter which returns a comma-separated list of the group names, and also skips the automatic 'trust level' groups. Then, we can reference that getter from the template, just like any other property:

```gjs
// (existing imports omitted)

export default class CustomWelcomeBanner extends Component {
  @service currentUser;

  get commaSeparatedGroups() {
    return this.currentUser?.groups
      .reject((group) => group.name.startsWith("trust_level_"))
      .map((group) => group.name)
      .join(", ");
  }

  <template>
    <div class="custom-welcome-banner">
      {{#if this.username}}
        Welcome back @{{this.username}}. You're a member of
        {{this.commaSeparatedGroups}}.
      {{else}}
        Welcome to our community.
      {{/if}}
    </div>
  </template>
}
```

## Using core components

Themes can import and use any components from Discourse core. The majority of them can be found [in this directory](https://github.com/discourse/discourse/tree/main/frontend/discourse/app/components) of the core repository. Some of these are very specific to certain use-cases in core, and probably won't be useful for plugins. But others are more generic, and are designed to be reused from anywhere.

The most-used component is `DButton`. As the name suggests, that can be used to render an HTML `<button>`, but with a little extra Discourse flair. To import it, add this to the top of your `custom-welcome-banner.gjs` file:

```gjs
import DButton from "discourse/components/d-button";
```

Let's swap out our welcome message with something a little more interactive, so we can try out the button:

```gjs
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";

export default class CustomWelcomeBanner extends Component {
  @tracked counter = 0;

  @action
  incrementCounter() {
    this.counter++;
  }

  <template>
    <div class="custom-welcome-banner">
      Count:
      {{this.counter}}
      <DButton
        @icon="plus"
        @translatedLabel="Increment"
        @action={{this.incrementCounter}}
      />
    </div>
  </template>
}
```

Lots going on here! Let's break it down:

1. We created a new `counter` field in the component, so we can keep track of an integer.

2. We imported the `@tracked` decorator and applied it to the `counter` field. This allows Ember's autotracking system to automatically re-render relevant parts of the DOM when the field value is changed

3. We created a new function in the component which will increment the counter when called
4. We imported the `@action` decorator and applied it to the `incrementCounter()` function. This makes the function usable from a template context. [^1]

5. We imported the `DButton` component, and added it to the template in a similar way to a regular HTML element. We passed three arguments to it: `@icon`, `@translatedLabel` and `@action`.

[^1]: technically: it creates a 'bound' version of the function for each component instance, and ensures the function runs in the context of an ember runloop

Once you've made those changes and saved, you should see the counter interface in the banner. Every time you click the button, the number will go up.

Now we know how to use other components from our theme! To learn more about all of this, we recommend you check out [the Ember guides](https://guides.emberjs.com/release/), and read through code from other Discourse themes, plugins, or core.

[Next up](https://meta.discourse.org/t/357801) we'll take a look at some of the other JS-based customization which Discourse offers.
