---
title: Customizing the topic list
short_title: Topic List Customization
id: customizing-topic-list
---

The topic-list is one of the most-used and most-customized user-interfaces in Discourse. There are many different tools available to theme and plugin developers to achieve this customization, each with their own advantages, disadvantages and maintenance considerations.

## CSS-based Customization

The safest and most common customization method is CSS. As with any other Discourse customization: the more complex your changes, the more maintenance is likely to be required in your theme or plugin.

General guidance on CSS customization can be found in [the Designer's Guide](https://meta.discourse.org/t/designers-guide-to-getting-started-with-themes-in-discourse/152002).

## Adding, removing and rearranging columns

Discourse default topic list on Desktop is rendered as a table. The [JS plugin API](https://meta.discourse.org/t/41281) can be used to customize the set of columns by adding, removing, replacing or reordering them. This surgical modification of columns means that your theme or plugin is making the smallest possible change, so that core changes are unlikely to conflict with it in future.

The topic-list columns are represented by a 'DAG API' object, accessible via the `topic-list-columns` [Value Transformer](https://meta.discourse.org/t/349954). Each column is represented by a plain JS object with two keys:

- `header`: An Ember Component to be rendered as the header cell for this column
- `item`: An Ember Component to be rendered as the item cell for this column

A list of arguments passed to header cells can be found [here](https://github.com/discourse/discourse/blob/b76c5406bd/app/assets/javascripts/discourse/app/components/topic-list/header.gjs#L6C5-L29C14), and a list of arguments passed to item cells can be found [here](https://github.com/discourse/discourse/blob/b76c5406bdd4a9277a0bfc85c54b92a78f6ce48a/app/assets/javascripts/discourse/app/components/topic-list/item.gjs#L384C11-L395C20). Core's default columns can be found [here](https://github.com/discourse/discourse/blob/b76c5406bdd4a9277a0bfc85c54b92a78f6ce48a/app/assets/javascripts/discourse/app/components/topic-list/list.gjs#L44-L88).

This example adds, removes and repositions columns in the desktop topic list:

```gjs
// .../discourse/api-initializers/my-topic-list-customization.gjs

import { apiInitializer } from "discourse/lib/api";

const StaffHeaderCell = <template>
  <th>Staff?</th>
</template>;
const StaffItemCell = <template>
  <td>{{if @topic.creator.staff "✅"}}</td>
</template>;

export default apiInitializer("1.34", (api) => {
  const discoveryService = api.container.lookup("service:discovery");

  api.registerValueTransformer("topic-list-columns", ({ value: columns }) => {
    // Remove the core column which shows poster avatars:
    columns.delete("posters");

    // Swap the "replies" and "views" columns:
    columns.reposition("views", { before: "replies" });

    // Lean on external autotracked state to make decisions:
    if (discoveryService.category?.slug === "announcements") {
      // Add a custom column:
      columns.add("created-by-staff", {
        header: StaffHeaderCell,
        item: StaffItemCell,
      });
    }

    return columns;
  });
});
```

## Introducing content via Plugin Outlets

Plugin outlets can be used to inject content into existing cells on desktop, or to inject content into the mobile view. These can be identified and used in the same way as any other part of Discourse. Check out [the Plugin Outlet documentation](https://meta.discourse.org/t/using-plugin-outlet-connectors-from-a-theme-or-plugin/32727).

## Replacing the entire topic-list-item

If you want to completely replace the core topic-list-item implementation, then you can use the `topic-list-item` Wrapper Plugin Outlet. This should only be done when your design differs so much from core that you don't want it to be affected by future core changes, and you don't need it to be compatible with other themes / plugins.

If using this strategy, you should take extra care to ensure that your code is well tested, and you should make sure that your theme/plugin users are aware of the caveats.

## Other tweaks via Transformers and Theme Modifiers

A number of [Value Transformers](https://meta.discourse.org/t/349954) allow making surgical tweaks to core's topic-list implementation. The most common ones are:

- **`topic-list-class`** (context: `{ topics }`) - an array of classes to be applied to the topic list `<table>` element

- **`topic-list-item-class`** (context: `{ topic, index }`) - an array of classes to be applied to the topic-list-item's `<tr>` element

- **`topic-list-item-expand-pinned`** (context: `{ topic, mobileView }`) - a boolean which determines whether the topic excerpt should be displayed. (see also: `serialize_topic_excerpts` Theme Modifier)

- **`topic-list-item-mobile-layout`** (context: `{ topic }`) - a boolean which determines whether to use the mobile topic-list layout. Transforming this value can allow the desktop view to be used everywhere, which may be useful if you'd like to build a fully 'responsive' styling for the topic list.

Some [Theme Modifiers](https://meta.discourse.org/t/150605) are also relevant to the topic list. For example:

- **`serialize_topic_excerpts`** (boolean) (default false) - always include excerpts when serializing topic lists

- **`topic thumbnails`** (array of dimensions) - request additional resolutions in the topic thumbnail set
