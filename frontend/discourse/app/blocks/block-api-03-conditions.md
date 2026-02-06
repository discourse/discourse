# Block API: Conditions

> **Navigation:** [Getting Started](block-api-getting-started.md) | [Concepts](block-api-01-concepts.md) | [Architecture](block-api-02-architecture.md) | **Conditions** | [Runtime](block-api-04-runtime.md) | [Internals](block-api-05-internals.md) | [Reference](block-api-06-reference.md) | [Authoring](block-api-authoring.md)

---

Every visibility rule is a **condition**—a declarative object that the system evaluates at render time. No imperative code, just data describing what should be true for a block to show.

```javascript
{ type: "user", loggedIn: true }           // Check user state
{ type: "route", pages: ["TOPIC_PAGES"] }  // Check current page
{ type: "setting", name: "dark_mode" }     // Check a setting
```

Conditions can see:
- **Outlet args** passed from the template via `@outletArgs`
- Injected **Services** like `currentUser`, `siteSettings`, `router` (in custom conditions)
- **Debug context** when logging is enabled

**The `source` parameter:** Some conditions support a `source` parameter that changes *what* they check. By default, the `user` condition checks the person viewing the page, and the `setting` condition checks site settings. But what if you're on a user profile page and want to show a badge based on the *profile owner's* trust level, not the viewer's? The `source` parameter lets you redirect the condition to check a different data source.

---

## Built-in Conditions

Five condition types ship with Discourse:

| When you want to... | Use this condition |
|---------------------|-------------------|
| Show content based on who's viewing (logged in, admin, trust level) | `user` |
| Check a site or theme setting | `setting` |
| Respond to screen size or device type | `viewport` |
| Check data passed from the template (topic properties, user objects) | `outlet-arg` |
| Match specific pages, URLs, or navigation contexts | `route` |

Most blocks need only one or two condition types. Start with the simplest condition that achieves your goal.

---

### User Condition

Control visibility based on who's viewing—whether they're logged in, their role (admin, moderator, staff), their trust level, or their group membership.

By default, checks the **current user**—the person viewing the page. Use the `source` option to check a *different* user (topic author, profile owner, etc.).

| Property | Type | Description |
|----------|------|-------------|
| `loggedIn` | `boolean` | true = must be logged in, false = must be anonymous |
| `admin` | `boolean` | true = must be admin |
| `moderator` | `boolean` | true = must be moderator (admins also pass) |
| `staff` | `boolean` | true = must be staff member |
| `minTrustLevel` | `number` (0-4) | Minimum trust level required |
| `maxTrustLevel` | `number` (0-4) | Maximum trust level allowed |
| `groups` | `string[]` | Must be in at least one of these groups (OR logic) |
| `source` | `string` | Check a different user object from outlet args |

**Examples:**

```javascript
// Basic checks
{ type: "user", loggedIn: true }           // Only logged-in users
{ type: "user", admin: true }              // Only admins
{ type: "user", staff: true }              // Admins and moderators
{ type: "user", minTrustLevel: 2 }         // Trust level 2 and above
{ type: "user", groups: ["beta-testers"] } // Members of beta-testers group

// Multiple properties use AND logic
{ type: "user", loggedIn: true, minTrustLevel: 2, groups: ["beta-testers"] }

// Check outlet arg user instead of current user
{ type: "user", source: "@outletArgs.topicAuthor", admin: true }
```

**Choosing the right check:** Use `staff` when moderators and admins should see the same thing. Use `admin` or `moderator` separately when their experiences should differ. Use `groups` for feature rollouts to specific user segments.

---

### Setting Condition

Tie block visibility to site configuration. Show a promo banner only when a setting is enabled, or change content based on a dropdown setting's value.

| Property | Type | Description |
|----------|------|-------------|
| `name` | `string` | Setting key (required) |
| `enabled` | `boolean` | true = setting truthy, false = setting falsy |
| `equals` | `any` | Exact value match |
| `includes` | `array` | Setting value is in this array (for enum settings) |
| `contains` | `string` | List setting contains this value |
| `containsAny` | `array` | List setting contains any of these values |
| `source` | `object` | Custom settings object (e.g., theme settings) |

**Only one comparison mode per condition:**

```javascript
// WRONG - multiple comparison modes
{ type: "setting", name: "foo", enabled: true, equals: "bar" }

// RIGHT - one comparison mode
{ type: "setting", name: "foo", enabled: true }
{ type: "setting", name: "foo", equals: "bar" }
```

**Theme settings:**

```javascript
import { settings } from "virtual:theme";

// Check theme setting instead of site setting
{ type: "setting", source: settings, name: "show_sidebar", enabled: true }
```

---

### Viewport Condition

Respond to screen size and device type. Use when you want to show completely different blocks on different screen sizes, or prevent a component from rendering entirely below a certain size.

> :bulb: For simple show/hide scenarios, CSS media queries are usually more performant. Use viewport conditions when you need to *prevent rendering entirely* or combine viewport checks with other conditions.

**Breakpoints:**

| Name | Min Width | Description |
|------|-----------|-------------|
| `sm` | 40rem (640px) | Larger phones, small tablets |
| `md` | 48rem (768px) | Tablets |
| `lg` | 64rem (1024px) | Laptops, small desktops |
| `xl` | 80rem (1280px) | Desktops |
| `2xl` | 96rem (1536px) | Large desktops |

| Property | Type | Description |
|----------|------|-------------|
| `min` | `string` | Viewport must be at least this size |
| `max` | `string` | Viewport must be at most this size |
| `touch` | `boolean` | true = touch device only, false = non-touch only |

**Examples:**

```javascript
// Large screens only
{ type: "viewport", min: "lg" }

// Small screens only
{ type: "viewport", max: "sm" }

// Medium to large screens
{ type: "viewport", min: "md", max: "xl" }

// Touch devices only
{ type: "viewport", touch: true }
```

---

### OutletArg Condition

Make visibility decisions based on data passed via `@outletArgs`. Build context-aware blocks—showing a "mark as solved" button only on unsolved topics, or displaying author badges only when viewing a staff member's profile.

| Property | Type | Description |
|----------|------|-------------|
| `path` | `string` | Dot-notation path to property (required) |
| `value` | `any` | Value to match (see matching rules) |
| `exists` | `boolean` | true = property exists, false = property undefined |

> :warning: You cannot use both `value` and `exists` together—they are mutually exclusive.

**Value matching rules:**
- Primitive value → passes if target === value (strict equality)
- `[a, b, c]` → passes if target matches ANY element (OR logic)
- `{ not: x }` → passes if target does NOT match x
- `{ any: [...] }` → passes if target matches ANY spec in array (OR logic)
- RegExp → passes if target (coerced to string) matches the pattern

**Examples:**

```javascript
// Check if topic is closed
{ type: "outlet-arg", path: "topic.closed", value: true }

// Check trust level is 2, 3, or 4
{ type: "outlet-arg", path: "user.trust_level", value: [2, 3, 4] }

// Check topic is NOT closed
{ type: "outlet-arg", path: "topic.closed", value: { not: true } }

// Check if topic property exists
{ type: "outlet-arg", path: "topic", exists: true }
```

---

### Route Condition

Target specific pages, entire sections of the site, or precisely filtered views. Show a promo only on the homepage, a sidebar panel only on category pages, or a feature announcement only on the latest topics list with a specific query parameter.

```javascript
{ type: "route", urls: [...], pages: [...], params: {...}, queryParams: {...} }
```

> **Why URLs instead of Ember route names?** Using internal route names would make them part of the public API—any rename would break plugins and themes. URLs are already effectively public: changing them breaks bookmarks, external links, and SEO.

**Two approaches:**
- **`urls`**: Match URL patterns using glob syntax—precise path control
- **`pages`**: Match semantic page types—logical section targeting that survives URL changes

#### URL Patterns (`urls`)

Uses [picomatch](https://github.com/micromatch/picomatch) glob syntax:

| Pattern | Matches |
|---------|---------|
| `"/latest"` | Exact path |
| `"/c/*"` | Single segment (`/c/foo` but not `/c/foo/bar`) |
| `"/c/**"` | Multi-segment (`/c/foo`, `/c/foo/bar`, etc.) |
| `"/t/*/**"` | Combined (`/t/123/slug`, `/t/123/slug/4`) |
| `"/{latest,top}"` | Brace expansion (matches either) |

> **Subfolder installations:** URL matching automatically handles subfolders by normalizing URLs before matching.

#### Semantic Page Types (`pages`)

| Page Type | Description | Parameters |
|-----------|-------------|------------|
| `CATEGORY_PAGES` | Category listing pages | `categoryId`, `categorySlug`, `parentCategoryId` |
| `TAG_PAGES` | Tag listing pages | `tagId`, `categoryId`, `categorySlug`, `parentCategoryId` |
| `DISCOVERY_PAGES` | Discovery routes (latest, top, etc.) | `filter` |
| `HOMEPAGE` | Custom homepage only | (none) |
| `TOP_MENU` | Top nav discovery routes | `filter` |
| `TOPIC_PAGES` | Individual topic pages | `id`, `slug` |
| `USER_PAGES` | User profile pages | `username` |
| `ADMIN_PAGES` | Admin section pages | (none) |
| `GROUP_PAGES` | Group pages | `name` |

**Choosing between URLs and Pages:**

Choose `pages` when:
- You want to match a logical section (all category pages, all topic pages)
- You need typed parameters like `categoryId` or `username`

Choose `urls` when:
- You need exact path matching
- You're targeting custom routes not covered by page types
- You need glob patterns for a specific URL structure

#### Page Parameters (`params`)

Works only with `pages` (not `urls`) and validates parameters against page type definitions:

```javascript
// Match specific category by ID
{ type: "route", pages: ["CATEGORY_PAGES"], params: { categoryId: 5 } }

// Match category by slug
{ type: "route", pages: ["CATEGORY_PAGES"], params: { categorySlug: "general" } }

// Match discovery pages with specific filter
{ type: "route", pages: ["DISCOVERY_PAGES"], params: { filter: "latest" } }

// Match specific tag filtered by category
{ type: "route", pages: ["TAG_PAGES"], params: { tagId: "javascript", categoryId: 5 } }

// Multiple page types (OR logic)
{ type: "route", pages: ["CATEGORY_PAGES", "TAG_PAGES"] }
```

**Params with `any` and `not` operators:**

```javascript
// Match if category ID is 1, 2, or 3 (OR logic)
{
  type: "route",
  pages: ["CATEGORY_PAGES"],
  params: { any: [{ categoryId: 1 }, { categoryId: 2 }, { categoryId: 3 }] }
}

// Match if category ID is NOT 10 (negation)
{
  type: "route",
  pages: ["CATEGORY_PAGES"],
  params: { not: { categoryId: 10 } }
}
```

#### Query Parameters (`queryParams`)

Works with both `urls` and `pages`:

```javascript
// Simple query param match
{ type: "route", urls: ["/latest"], queryParams: { filter: "solved" } }

// Multiple query params (AND - all must match)
{ type: "route", pages: ["DISCOVERY_PAGES"], queryParams: { filter: "solved", order: "activity" } }

// OR logic
{ type: "route", pages: ["DISCOVERY_PAGES"], queryParams: { any: [{ filter: "solved" }, { filter: "open" }] } }

// NOT logic
{ type: "route", pages: ["DISCOVERY_PAGES"], queryParams: { not: { filter: "closed" } } }
```

#### Excluding Pages

Use the NOT combinator:

```javascript
// Show on all pages EXCEPT admin pages
{ not: { type: "route", pages: ["ADMIN_PAGES"] } }

// Show on all pages EXCEPT specific URLs
{ not: { type: "route", urls: ["/admin/**", "/wizard/**"] } }

// Show on discovery pages EXCEPT the homepage
[
  { type: "route", pages: ["DISCOVERY_PAGES"] },
  { not: { type: "route", pages: ["HOMEPAGE"] } }
]
```

---

## Combining Conditions

When blocks need more than one check, use familiar boolean logic: AND, OR, and NOT operators.

### Single Condition

Pass the condition object directly:

```javascript
conditions: { type: "user", loggedIn: true }
```

### AND Logic (Array)

All conditions must pass:

```javascript
conditions: [
  { type: "user", loggedIn: true },
  { type: "route", pages: ["DISCOVERY_PAGES"] }
]
```

### OR Logic (`any` Wrapper)

At least one condition must pass:

```javascript
conditions: {
  any: [
    { type: "user", admin: true },
    { type: "user", moderator: true }
  ]
}
```

### NOT Logic (`not` Wrapper)

Invert a condition:

```javascript
conditions: { not: { type: "route", pages: ["ADMIN_PAGES"] } }
```

### Nesting for Complex Requirements

Patterns can be nested. Arrays inside `any` create AND groups within OR logic:

```javascript
// Show for: logged in users who are either admins OR (TL2+ and not on admin pages)
conditions: [
  { type: "user", loggedIn: true },
  {
    any: [
      { type: "user", admin: true },
      [
        { type: "user", minTrustLevel: 2 },
        { not: { type: "route", pages: ["ADMIN_PAGES"] } }
      ]
    ]
  }
]
```

Think of it like boolean algebra: arrays are AND, `any` is OR, `not` inverts.

---

## Custom Conditions

Need something the built-ins don't cover? Create your own with the `@blockCondition` decorator and a class that extends `BlockCondition`.

> :bulb: **Namespace Requirements:** Condition type names follow the same namespacing rules as blocks:
> - **Plugins** must use `namespace:condition-name` format (e.g., `"my-plugin:feature-flag"`)
> - **Themes** must use `theme:namespace:condition-name` format (e.g., `"theme:mytheme:dark-mode"`)
> - **Core** conditions use simple names without a namespace prefix

**Example: Feature Flag Condition**

```javascript
import { BlockCondition, blockCondition } from "discourse/blocks/conditions";
import { service } from "@ember/service";

@blockCondition({
  type: "my-plugin:feature-flag",  // Plugin conditions must be namespaced
  args: {
    flag: { type: "string", required: true, pattern: /^[a-z][a-z0-9_]*$/ },
    enabled: { type: "boolean" },
  },
})
export default class FeatureFlagCondition extends BlockCondition {
  @service featureFlags;

  evaluate(args) {
    const { flag, enabled = true } = args;
    const isEnabled = this.featureFlags.isEnabled(flag);
    return enabled ? isEnabled : !isEnabled;
  }
}
```

**Registering custom conditions:**

```javascript
// plugins/my-plugin/assets/javascripts/discourse/pre-initializers/register-conditions.js
import { withPluginApi } from "discourse/lib/plugin-api";
import FeatureFlagCondition from "../blocks/conditions/feature-flag";

export default {
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlockConditionType(FeatureFlagCondition);
    });
  },
};
```

> :exclamation: **Important:** Registration must happen in a pre-initializer that runs before `"freeze-block-registry"`.

**Using the custom condition:**

```javascript
{
  block: MyBlock,
  conditions: { type: "my-plugin:feature-flag", flag: "new_feature", enabled: true }
}
```

---

## Simple by Default

The API balances simplicity for common cases with power for advanced use:

```javascript
// Just show a block
{ block: WelcomeBanner }

// Add args when needed
{ block: WelcomeBanner, args: { title: "Hello" } }

// Add conditions when needed
{
  block: WelcomeBanner,
  args: { title: "Hello" },
  conditions: { type: "user", loggedIn: true }
}

// Add complex logic when needed
{
  block: WelcomeBanner,
  args: { title: "Hello" },
  conditions: [
    { type: "user", loggedIn: true },
    {
      any: [
        { type: "user", admin: true },
        { type: "user", minTrustLevel: 2 }
      ]
    },
    { not: { type: "route", urls: ["/admin/**"] } }
  ]
}
```

Start simple, add complexity only when you need it.

---

> **Next:** [Runtime](block-api-04-runtime.md) — How the evaluation engine works, error handling, and debugging tools
