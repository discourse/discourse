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

On desktop, the topic list is rendered as a table. On mobile, each topic row uses a separate single-cell layout, so `topic-list-columns` only affects the desktop table.

The [Plugin API](12-pluginapi.md) can be used to customize the desktop columns via the `topic-list-columns` [Value Transformer](23-transformers.md). This is the most surgical way to add, remove, replace, or reorder columns without taking ownership of the full row markup.

`topic-list-columns` is a **mutable** transformer. Core builds a `DAG` of columns, passes that mutable object through registered transformers, and resolves it afterwards. In practice, that means you should mutate the `columns` object directly.

The transformer callback currently receives:

- `context.listContext`
- `context.category`
- `context.filter`

Current core column keys are:

- `bulk-select` when bulk select is enabled
- `topic`
- `posters` when poster avatars are enabled
- `replies`
- `likes` or `op-likes` depending on the current sort order
- `views`
- `activity`

Each column value can define:

- `header`: the component rendered in the table header for that column
- `item`: the component rendered in each desktop row for that column

The `DAG` instance supports these methods:

- `add(key, value, position?)`
- `delete(key)`
- `replace(key, value, position?)`
- `reposition(key, position)`

When you call `replace()`, core preserves the existing `header` or `item` if your replacement only provides one of them.

Header cell components currently receive these arguments:

| Argument             | Description                                           |
| -------------------- | ----------------------------------------------------- |
| `@sortable`          | Whether the column should behave as a sortable header |
| `@activeOrder`       | The currently active sort order                       |
| `@changeSort`        | Callback used to change sorting                       |
| `@ascending`         | Whether the active sort is ascending                  |
| `@category`          | The current category, when available                  |
| `@name`              | The translation key or label used by the header       |
| `@bulkSelectEnabled` | Whether bulk select mode is active                    |
| `@showBulkToggle`    | Whether the bulk-select toggle button should be shown |
| `@canBulkSelect`     | Whether bulk select is available                      |
| `@canDoBulkActions`  | Whether bulk actions are currently available          |
| `@bulkSelectHelper`  | The bulk-select helper object                         |

Item cell components currently receive these arguments:

| Argument               | Description                                |
| ---------------------- | ------------------------------------------ |
| `@topic`               | The current topic                          |
| `@bulkSelectEnabled`   | Whether bulk select mode is active         |
| `@onBulkSelectToggle`  | Callback used by the bulk-select checkbox  |
| `@isSelected`          | Whether the topic is currently selected    |
| `@showTopicPostBadges` | Whether unread/new badges should be shown  |
| `@hideCategory`        | Whether category markup should be hidden   |
| `@tagsForUser`         | The current tag visibility context         |
| `@expandPinned`        | Whether the pinned excerpt should be shown |

Current source for this API lives in `frontend/discourse/app/components/topic-list/list.gjs`, `frontend/discourse/app/components/topic-list/header.gjs`, and `frontend/discourse/app/components/topic-list/item.gjs`.

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

export default apiInitializer((api) => {
  api.registerValueTransformer(
    "topic-list-columns",
    ({ value: columns, context }) => {
      // Remove the core column which shows poster avatars:
      columns.delete("posters");

      // Swap the "replies" and "views" columns:
      columns.reposition("views", { before: "replies" });

      if (context.category?.slug === "announcements") {
        columns.add(
          "created-by-staff",
          {
            header: StaffHeaderCell,
            item: StaffItemCell,
          },
          { before: "activity" }
        );
      }
    }
  );
});
```

## Introducing content via Plugin Outlets

Prefer [Plugin Outlets](13-plugin-outlet-connectors.md) when you want to inject content without taking ownership of the whole row structure.

Some of the most useful topic-list outlets are:

| Outlet                                                                                               | Purpose                                   | Outlet args                                                                                                                               |
| ---------------------------------------------------------------------------------------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `before-topic-list-body` / `after-topic-list-body`                                                   | Add markup before or after the table body | `topics`, `selected`, `bulkSelectEnabled`, `lastVisitedTopic`, `discoveryList`, `hideCategory`                                            |
| `after-topic-list-item`                                                                              | Insert an extra `<tr>` after each row     | `topic`, `index`                                                                                                                          |
| `topic-list-item`                                                                                    | Wrap or replace the entire row            | `topic`, `bulkSelectEnabled`, `onBulkSelectToggle`, `isSelected`, `hideCategory`, `tagsForUser`, `showTopicPostBadges`, `navigateToTopic` |
| `topic-list-topic-cell-link-top-line`                                                                | Extend the desktop title/status line      | `topic`, `tagsForUser`                                                                                                                    |
| `topic-list-topic-cell-link-bottom-line`                                                             | Extend the desktop category/tag/meta line | `topic`, `tagsForUser`                                                                                                                    |
| `topic-list-item-mobile-avatar` / `topic-list-item-mobile-bumped-at`                                 | Mobile-only customizations                | `topic`                                                                                                                                   |
| `topic-list-before-reply-count` / `topic-list-before-view-count` / `topic-list-before-relative-date` | Add content near the count/date cells     | `topic`                                                                                                                                   |
| `topic-list-heading-bottom`                                                                          | Add content inside sortable header cells  | `name`, `bulkSelectEnabled`                                                                                                               |

There are more outlets throughout `frontend/discourse/app/components/topic-list/`, especially in `item/topic-cell.gjs`, `item/replies-cell.gjs`, `item/views-cell.gjs`, and `item/activity-cell.gjs`.

## Replacing the entire topic-list-item

If you want to completely replace the core row implementation, use the `topic-list-item` wrapper outlet. This should only be done when your design differs so much from core that you do not want future core changes to affect it, and you do not need compatibility with other themes or plugins.

Core intentionally does **not** pass `@columns` into this wrapper outlet. A full row replacement means taking ownership of the row structure yourself.

If using this strategy, you should take extra care to ensure that your code is well tested, and you should make sure that your theme/plugin users are aware of the caveats.

## Other tweaks via Transformers and Theme Modifiers

A number of [Transformers](23-transformers.md) allow small, targeted changes to the topic-list implementation:

- **`topic-list-columns`** (mutable context: `{ listContext, category, filter }`) - mutate the desktop column DAG
- **`topic-list-class`** (context: `{ topics, listContext }`) - return classes to add to the topic list `<table>`
- **`topic-list-item-class`** (context: `{ topic, index, listContext }`) - return classes to add to each topic row
- **`topic-list-item-style`** (context: `{ topic, index, listContext }`) - return an array of `htmlSafe` CSS declarations to be joined into the row's inline `style`
- **`topic-list-item-expand-pinned`** (context: `{ topic, mobileView }`) - control whether the topic excerpt is displayed
- **`topic-list-item-mobile-layout`** (context: `{ topic, listContext }`) - choose whether a row uses the mobile layout
- **`topic-list-header-sortable-column`** - override whether header cells are sortable, for example based on the current category

There is also a **behavior transformer** for row clicks:

- **`topic-list-item-click`** (context: `{ event, topic, listContext, navigateToTopic }`) - wrap or override the default click behavior. Register this with `api.registerBehaviorTransformer(...)`, not `api.registerValueTransformer(...)`.

For example, `topic-list-item-style` must return `htmlSafe` strings:

```gjs
// .../discourse/api-initializers/topic-list-style.gjs

import { htmlSafe } from "@ember/template";
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.registerValueTransformer(
    "topic-list-item-style",
    ({ value, context }) => {
      if (context.topic.pinned) {
        value.push(htmlSafe("outline: 2px solid var(--primary-low);"));
      }

      return value;
    }
  );
});
```

Some [Theme Modifiers](../05-themes-components/21-theme-modifiers.md) are also relevant to the topic list because they change which data is serialized:

- **`serialize_topic_excerpts`** (`boolean`, default `false`) - always include excerpts when serializing topic lists
- **`topic_thumbnail_sizes`** (`array`) - request additional resolutions in the topic thumbnail set
- **`serialize_topic_op_likes_data`** (`boolean`) - include first-post like data such as `op_like_count`, `op_can_like`, `op_liked`, and `first_post_id`
- **`serialize_topic_is_hot`** (`boolean`) - include `is_hot` on topic list items
