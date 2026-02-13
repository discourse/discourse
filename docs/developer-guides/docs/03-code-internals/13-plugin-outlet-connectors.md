---
title: Using Plugin Outlet Connectors from a Theme or Plugin
short_title: Plugin outlet connectors
id: plugin-outlet-connectors
---

Discourse includes hundreds of Plugin Outlets which can be used to inject new content or replace existing contend in the Discourse UI. 'Outlet arguments' are made available so that content can be customized based on the context.

# Choosing an outlet

To find the name of a plugin outlet, search Discourse core for "`<PluginOutlet`", or use the [plugin outlet locations](https://meta.discourse.org/t/plugin-outlet-locations-theme-component/100673) theme component. (e.g. `topic-above-posts`).

# Wrapper outlets

Some outlets in core look like `<PluginOutlet @name="foo" />`. These allow you to inject new content. Other outlets will 'wrap' an existing core implementation like this

```hbs
<PluginOutlet @name="foo">
  core implementation
</PluginOutlet>
```

Defining a connector for this kind of 'wrapper' outlet will replace the core implementation. Only one active theme/plugin can contribute a connector for a wrapper plugin outlet.

For wrapper plugin outlets, you can render the original core implementation using the `{{yield}}` keyword. This can be helpful if you only want to replace the core implementation under certain conditions, or if you would like to wrap it in something.

# Defining the template

Once you've chosen an outlet, decide on a name for your connector. This needs to be unique across all themes / plugins installed on a given community. e.g. `brand-official-topics`

In your theme / plugin, define a new handlebars template with a path formatted like this:

> :art: `{theme}/javascripts/discourse/connectors/{outlet-name}/{connector-name}.hbs`
>
> :electric_plug: `{plugin}/assets/javascripts/discourse/connectors/{outlet-name}/{connector-name}.hbs`

The content of these files will be rendered as an Ember Component. For general information on Ember / Handlebars, check out [the Ember guides](https://guides.emberjs.com/release/components/).

For our hypothetical "brand official topics" connector, the template might look like

```hbs
<div class="alert alert-info">
  This topic was created by a member of the
  <a href="https://discourse.org/team">Discourse Team</a>
</div>
```

Some plugin outlets will automatically wrap your content in an HTML element. The element type is defined by `@connectorTagName` on the `<PluginOutlet>`.

[quote]
[details=ℹ️ Removing the automatic wrapper element]
Modern plugin outlets (with `defaultGlimmer=true`) render connectors as 'template only glimmer components', which are significantly faster to render and have no wrapper element. Eventually, this will be used everywhere.

To use this new rendering technique on existing plugin outlets, create an adjacent JS file with this content:

```js
import templateOnly from "@ember/component/template-only";
export default templateOnly();
```

If you need custom logic as well, see the other ℹ️ sections below.
[/details]
[/quote]

# Using outlet arguments

Plugin Outlets provide information about the surrounding context via `@outletArgs`. The arguments passed to each outlet vary. An easy way to view the arguments is to add this to your template:

```hbs
{{log @outletArgs}}
```

This will log the arguments to your browser's developer console. They will appear as a `Proxy` object - to explore the list of arguments, expand the `[[Target]]` of the proxy.

In our `topic-above-posts` example, the rendered topic is available under `@outletArgs.model`. So we can add the username of the team member like this:

```hbs
<div class="alert alert-info">
  This topic was created by
  {{@outletArgs.model.details.created_by.username}}
  (a member of the
  <a href="https://discourse.org/team">Discourse Team</a>)
</div>
```

[quote]
[details=ℹ️ Legacy ways to access arguments]
In many Plugin Outlets, by default it is possible to access arguments using `{{argName}}` or `{{this.argName}}`. For now, this still works in existing outlets.

New plugin outlets (with `@defaultGlimmer={{true}}`) render connectors as 'template only glimmer components', which do not have a `this` context. Eventually, existing Plugin Outlets will also be migrated to this pattern. The `@outletArgs` technique is best because it will work consistently in both classic and glimmer plugin outlets.
[/details]
[/quote]

# Adding more complex logic

Sometimes, a simple handlebars template is not enough. To add Javascript logic to your connector, you can define a Javascript file adjacent to your handlebars template. This file should export a component definition. This functions just the same as any other component definition, and can include service injections.

Defining a component like this will remove the automatic `connectorTagName` wrapper element, so you may want to re-introduce an element of the same type in your hbs file.

In our `topic-above-posts` example, we may want to render the user differently based on the 'prioritize username in ux' site setting. A component definition for that might look something like this:

`.../connectors/topic-above-posts/brand-official-topic.js`:

```js
import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class BrandOfficialTopics extends Component {
  @service siteSettings;

  get displayName() {
    const user = this.args.outletArgs.model.details.created_by;
    if (this.siteSettings.prioritize_username_in_ux) {
      return user.username;
    } else {
      return user.name;
    }
  }
}
```

We can then update the template to reference the new getter:

```hbs
<div class="alert alert-info">
  This topic was created by
  {{this.displayName}}
  (a member of the
  <a href="https://discourse.org/team">Discourse Team</a>)
</div>
```

[quote]
[details=ℹ️ Legacy ways to define complex logic]
In older versions of Discourse, it wasn't possible to export a custom component definition. Instead, you could export an object with `setupComponent(args, component)` and `teardownComponent(component)` functions. This older technique is not officially deprecated yet, but we recommend switching to the new component-export approach going forwards.
[/details]
[/quote]

# Conditional rendering

If you only want your content to be rendered under certain conditions, it's often enough to wrap your template with a handlebars `{{#if}}` block. If that's not enough, you may want to use the `shouldRender` hook to control whether your connector template is rendered at all.

Firstly, ensure you have a `.js` connector definition as described above. Then, add a `static shouldRender()` function. Extending our example:

```js
import Component from "@glimmer/component";
import { getOwner } from "discourse-common/lib/get-owner";

export default class BrandOfficialTopics extends Component {
  static shouldRender(outletArgs, helper) {
    const firstPost = outletArgs.model.postStream.posts[0];
    return firstPost.primary_group_name === "team";
  }
  // ... (any other logic)
}
```

Now the connector will only be rendered when the first post of the topic was created by a team member.

`shouldRender` is evaluated in a Glimmer autotracking context. Future changes to any referenced properties (e.g. `outletArgs`) will cause the function to be re-evaluated.

[quote]
[details=ℹ️ shouldRender for templateOnly connectors]
If you'd like to define a `shouldRender` function without the overhead of a full component, you can do something like this:

```js
import templateOnly from "@ember/component/template-only";

export default Object.assign(templateOnly(), {
  shouldRender(outletArgs, helper) {
    // Logic here
  },
});
```

[/details]
[/quote]

[quote]
[details=ℹ️ Legacy shouldRender implementations]
**Autotracking:** Before Discourse 3.1, `shouldRender` would only be evaluated during initial render. Changes to referenced properties would not cause the function to be re-evaluated.

**Non-class syntax:** For now, defining a `shouldRender` function in a plain (non-class) javascript object is still supported, but we recommend moving towards a class-based or templateOnly-based syntax going forward.
[/details]
[/quote]

# Introducing new outlets

If you need an outlet that doesn't yet exist, please feel free to make a pull request, or open a topic in #dev.
