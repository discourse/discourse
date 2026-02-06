# Blocks API: Getting Started

---

## What Are Blocks?

Blocks are UI components that render in designated **outlets** throughout Discourse. Think of it like furniture arrangement:

- **Outlets** are rooms—designated spaces in the UI where content can go
- **Blocks** are furniture—self-contained components with defined specs
- **Themes** are the interior designer—they decide what goes where via `renderBlocks()`

Why blocks instead of plugin outlets? Blocks give you:
- **Declarative conditions** - Show content based on user state, route, settings, etc.
- **Validated args** - Catch typos and missing data at boot time, not runtime
- **Debug tools** - Visual overlays and console logging to see what's happening

This guide walks you through building your first block-based layout. By the end, you'll have a working homepage with conditional content that responds to user state.

---

## Documentation Guide

**If you learn by doing**, start here. This guide gets you building in 15 minutes. When you're ready to create your own blocks with custom validation and conditions, continue to [Authoring](block-api-authoring.md).

**If you prefer understanding the system first**, start with [Concepts](block-api-01-concepts.md) for the full mental model, then work through Architecture, Conditions, and Runtime.

For quick lookups, [Reference](block-api-06-reference.md) has API tables, troubleshooting tips, and a glossary.

---

## What You'll Build

A homepage layout with:
- A welcome banner that shows different messages for guests vs members
- A featured content section that only appears for logged-in users
- Proper structure using container blocks

Total time: ~15 minutes.

---

## Step 1: Create Your First Block

Let's start with a simple welcome banner. Create this file in your theme:

```gjs
// themes/my-theme/javascripts/discourse/blocks/welcome-banner.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

@block("theme:my-theme:welcome-banner", {
  args: {
    title: { type: "string", required: true },
    subtitle: { type: "string", default: "We're glad you're here." },
  },
})
export default class WelcomeBanner extends Component {
  <template>
    <div class="welcome-banner">
      <h1>{{@title}}</h1>
      <p class="welcome-banner__subtitle">{{@subtitle}}</p>
    </div>
  </template>
}
```

**What's happening here:**

- `@block("theme:my-theme:welcome-banner", {...})` decorates the component, giving it a name and defining what args it accepts
- `required: true` means callers must provide this arg—if they forget, they get a helpful error at boot time
- `default: "..."` provides a fallback value when the arg isn't specified
- The template uses `{{@title}}` and `{{@subtitle}}` to access the args

---

## Step 2: Render the Block

Now tell Discourse where to render your block. Create an api-initializer:

```javascript
// themes/my-theme/javascripts/discourse/api-initializers/configure-blocks.js
import { apiInitializer } from "discourse/lib/api";
import WelcomeBanner from "../blocks/welcome-banner";

export default apiInitializer((api) => {
  api.renderBlocks("homepage-blocks", [
    {
      block: WelcomeBanner,
      args: {
        title: "Welcome to Our Community",
        subtitle: "Join the conversation!",
      },
    },
  ]);
});
```

**That's it!** Your banner now renders in the `homepage-blocks` outlet. Visit your homepage to see it.

> :bulb: **Tip:** Since we're passing the class directly (`block: WelcomeBanner`), we don't need to register it. Registration is only needed when referencing blocks by string name.

---

## Step 3: Add Conditional Visibility

Let's make the banner smarter—show different content for guests vs logged-in users.

Update your api-initializer to use the `head` container block, which renders only the **first** child whose conditions pass:

```javascript
// themes/my-theme/javascripts/discourse/api-initializers/configure-blocks.js
import { apiInitializer } from "discourse/lib/api";
import WelcomeBanner from "../blocks/welcome-banner";

export default apiInitializer((api) => {
  api.renderBlocks("homepage-blocks", [
    {
      block: "head",  // Built-in: renders first matching child
      children: [
        {
          block: WelcomeBanner,
          args: {
            title: "Welcome Back!",
            subtitle: "Check out what's new since your last visit.",
          },
          conditions: { type: "user", loggedIn: true },
        },
        {
          block: WelcomeBanner,
          args: {
            title: "Welcome to Our Community",
            subtitle: "Sign up to join the conversation!",
          },
          // No conditions = fallback (always passes)
        },
      ],
    },
  ]);
});
```

**How it works:**

1. `head` evaluates children top-to-bottom
2. First child with passing conditions renders
3. The rest are skipped
4. A child with no conditions always passes—put your fallback last

Now logged-in users see "Welcome Back!" while guests see "Welcome to Our Community".

---

## Step 4: Add More Content with Groups

Let's add a featured section for members only. The `group` container holds multiple blocks together:

```javascript
import { apiInitializer } from "discourse/lib/api";
import WelcomeBanner from "../blocks/welcome-banner";
import FeaturedTopics from "../blocks/featured-topics";
import RecentActivity from "../blocks/recent-activity";
import QuickLinks from "../blocks/quick-links";

export default apiInitializer((api) => {
  api.renderBlocks("homepage-blocks", [
    // Welcome banner with guest/member variants (from Step 3)
    {
      block: "head",
      children: [
        {
          block: WelcomeBanner,
          args: { title: "Welcome Back!", subtitle: "Check out what's new." },
          conditions: { type: "user", loggedIn: true },
        },
        {
          block: WelcomeBanner,
          args: { title: "Welcome!", subtitle: "Sign up to join us!" },
        },
      ],
    },

    // Member dashboard - multiple blocks grouped together
    {
      block: "group",
      id: "member-dashboard",
      conditions: { type: "user", loggedIn: true },
      children: [
        { block: FeaturedTopics, args: { count: 5 } },
        { block: RecentActivity },
        { block: QuickLinks },
      ],
    },
  ]);
});
```

**Key points:**

- `group` renders ALL its visible children (unlike `head` which renders only the first match)
- The `id` generates a BEM class for styling: `.homepage-blocks__block-container--member-dashboard`
- Conditions on the group apply to the whole section—if the user isn't logged in, none of its children render

---

## Step 5: Combine Conditions

Conditions can be combined for more complex logic:

```javascript
// AND - all conditions must pass (use an array)
// Result: only logged-in users with trust level 2+ see this block
conditions: [
  { type: "user", loggedIn: true },
  { type: "user", minTrustLevel: 2 },
]

// OR - any condition can pass
// Result: staff members OR trust level 4 users see this block
conditions: {
  any: [
    { type: "user", staff: true },
    { type: "user", minTrustLevel: 4 },
  ],
}

// NOT - invert a condition
// Result: only guests (not logged in) see this block
conditions: { not: { type: "user", loggedIn: true } }
```

---

## Common Condition Types

**User conditions** - Check who's viewing:
```javascript
{ type: "user", loggedIn: true }           // Only logged-in users
{ type: "user", admin: true }              // Only admins
{ type: "user", staff: true }              // Admins and moderators
{ type: "user", minTrustLevel: 2 }         // Trust level 2 and above
{ type: "user", groups: ["beta-testers"] } // Members of beta-testers group
```

**Route conditions** - Check where they are:
```javascript
{ type: "route", pages: ["DISCOVERY_PAGES"] }  // Homepage, /latest, /top, etc.
{ type: "route", pages: ["TOPIC_PAGES"] }      // Viewing a topic
{ type: "route", pages: ["CATEGORY_PAGES"], params: { categorySlug: "support" } }  // Only in "support" category
```

**Setting conditions** - Check site configuration:
```javascript
{ type: "setting", name: "show_welcome_banner", enabled: true }  // Only if setting is enabled
```

**Viewport conditions** - Check screen size:
```javascript
{ type: "viewport", min: "lg" }  // Large screens and up (≥1024px)
{ type: "viewport", max: "md" }  // Medium screens and below (<768px)
```

---

## Using Plugin Blocks

Themes can compose layouts using blocks from plugins. Use string names with the `?` suffix for optional blocks:

```javascript
api.renderBlocks("homepage-blocks", [
  { block: "chat:recent-messages?" },     // Optional - silent if plugin missing
  { block: "solved:leaderboard?" },       // Optional
  { block: WelcomeBanner, args: {...} },  // Your theme's block
]);
```

Without `?`, a missing block causes a boot error. With `?`, it's silently skipped.

---

## Debugging

**Block not appearing?**

1. Open browser console—look for validation errors at boot
2. Enable **Console Logging** in the Block Debug tools (dev toolbar) to see condition evaluation
3. Enable **Visual Overlay** to see block boundaries and why hidden blocks failed

**Common errors:**

| Error | Cause | Fix |
|-------|-------|-----|
| "Unknown arg" | Typo in args | Check spelling, look for "did you mean?" suggestion |
| "Block not registered" | String reference to unregistered block | Register it or use `?` suffix |
| "Unknown condition type" | Typo in condition type | Check spelling: `user`, `route`, `setting`, `viewport`, `outlet-arg` |

---

## Quick Reference

**Block entry properties:**
```javascript
{
  block: WelcomeBanner,        // Required: class or "name" or "name?"
  args: { title: "Hi" },       // Optional: passed to component
  conditions: { type: ... },   // Optional: when to show
  id: "my-banner",             // Optional: for CSS targeting
  children: [...],             // Container blocks only
}
```

**Block naming:**
| Source | Format | Example |
|--------|--------|---------|
| Core | `name` | `group`, `head` |
| Plugin | `plugin:name` | `chat:recent-messages` |
| Theme | `theme:namespace:name` | `theme:tactile:hero-banner` |

---

## Next Steps

This guide showed you how to use existing blocks and compose layouts. To create your own blocks with custom validation, constraints, and conditions, continue to the Authoring guide.

- **[Authoring](block-api-authoring.md)** - Creating custom blocks, conditions, and containers
- **[Concepts](block-api-01-concepts.md)** - Conceptual deep-dive with the full mental model
- **[Reference](block-api-06-reference.md)** - Quick lookup for all options and patterns
