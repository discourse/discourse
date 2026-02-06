# Block API: Authoring

> **Navigation:** [Getting Started](block-api-getting-started.md) | [Concepts](block-api-01-concepts.md) | [Architecture](block-api-02-architecture.md) | [Conditions](block-api-03-conditions.md) | [Runtime](block-api-04-runtime.md) | [Internals](block-api-05-internals.md) | [Reference](block-api-06-reference.md) | **Authoring**

---

This guide walks you through building increasingly sophisticated blocks. You'll learn args validation, constraints, containers, and custom conditions by building a real feature: a configurable "featured content" system.

**Prerequisites:** Complete [Getting Started](block-api-getting-started.md) first.

---

## What You'll Build

A featured content system with:
- A `FeaturedTopics` block with validated, constrained args
- A `ContentGrid` container that arranges child blocks
- A custom `subscription` condition for premium content

Each section builds on the previous. By the end, you'll know how to create production-ready blocks.

---

## Part 1: A Block with Validated Args

Let's start with a block that displays featured topics. We want callers to configure it, but we need to validate their input.

### The Basic Block

```gjs
// blocks/featured-topics.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

@block("theme:my-theme:featured-topics", {
  description: "Displays a list of featured topics from a category or tag",
  args: {
    count: { type: "number", default: 5 },
  },
})
export default class FeaturedTopics extends Component {
  <template>
    <div class="featured-topics">
      <h3>Featured Topics</h3>
      <p>Showing {{@count}} topics</p>
      {{! Topic list would go here }}
    </div>
  </template>
}
```

This works, but `count` could be anything—negative numbers, huge values, decimals. Let's fix that.

### Adding Number Constraints

```gjs
@block("theme:my-theme:featured-topics", {
  args: {
    count: {
      type: "number",
      default: 5,
      min: 1,        // At least 1
      max: 20,       // No more than 20
      integer: true, // Whole numbers only
    },
  },
})
```

Now if someone tries `{ count: -5 }` or `{ count: 100 }`, they get a clear error at boot time:

```
Block "featured-topics" at blocks[0]:
Arg "count" value -5 is below minimum 1.
```

### Arg Types and Properties

Each arg has a `type` and type-specific validation properties:

| Type | Description | Validation Properties |
|------|-------------|----------------------|
| `string` | Text values | `minLength`, `maxLength`, `pattern`, `enum` |
| `number` | Numeric values | `min`, `max`, `integer`, `enum` |
| `boolean` | True/false | — |
| `array` | List of values | `itemType`, `itemEnum`, `minLength`, `maxLength` |
| `object` | Structured data | `properties`, `instanceOf`, `instanceOfName` |
| `any` | No type checking | — |

**Common properties (all types):**

| Property | Type | Description |
|----------|------|-------------|
| `required` | `boolean` | Must be provided (mutually exclusive with `default`) |
| `default` | varies | Value when not provided (mutually exclusive with `required`) |

**String properties:**

| Property | Type | Description |
|----------|------|-------------|
| `minLength` | `number` | Minimum character count |
| `maxLength` | `number` | Maximum character count |
| `pattern` | `RegExp` | Must match this regex |
| `enum` | `string[]` | Must be one of these values |

**Number properties:**

| Property | Type | Description |
|----------|------|-------------|
| `min` | `number` | Minimum value (inclusive) |
| `max` | `number` | Maximum value (inclusive) |
| `integer` | `boolean` | Must be a whole number |
| `enum` | `number[]` | Must be one of these values |

**Array properties:**

| Property | Type | Description |
|----------|------|-------------|
| `itemType` | `string` | Type of array items (`"string"`, `"number"`, etc.) |
| `itemEnum` | `array` | Allowed values for items |
| `minLength` | `number` | Minimum number of items |
| `maxLength` | `number` | Maximum number of items |

**Object properties:**

| Property | Type | Description |
|----------|------|-------------|
| `properties` | `object` | Nested arg schema for object shape |
| `instanceOf` | `Class` or `string` | Must be instance of class (e.g., `"model:user"`) |
| `instanceOfName` | `string` | Display name for error messages |

### Adding More Args

Our block needs to know *which* topics to feature. Let's add category and tag options:

```gjs
@block("theme:my-theme:featured-topics", {
  args: {
    count: {
      type: "number",
      default: 5,
      min: 1,
      max: 20,
      integer: true,
    },
    categoryId: { type: "number", integer: true },
    categorySlug: { type: "string" },
    tagName: { type: "string" },
    title: { type: "string", default: "Featured Topics" },
  },
})
```

But wait—we have a problem. Someone could pass both `categoryId` AND `categorySlug`, which is redundant. Or they could pass nothing, and we wouldn't know what to feature. We need **constraints**.

---

## Part 2: Cross-Arg Constraints

Constraints express rules that span multiple args.

### "At Least One" Constraint

We need either a category (by ID or slug) or a tag:

```gjs
@block("theme:my-theme:featured-topics", {
  args: {
    count: { type: "number", default: 5, min: 1, max: 20, integer: true },
    categoryId: { type: "number", integer: true },
    categorySlug: { type: "string" },
    tagName: { type: "string" },
    title: { type: "string", default: "Featured Topics" },
  },
  constraints: {
    atLeastOne: ["categoryId", "categorySlug", "tagName"],
  },
})
```

Now `{ count: 5 }` with no category or tag fails:

```
Block "featured-topics" at blocks[0]:
At least one of "categoryId", "categorySlug", "tagName" must be provided.
```

### "At Most One" Constraint

But we should prevent passing *both* `categoryId` and `categorySlug`—that's confusing:

```gjs
constraints: {
  atLeastOne: ["categoryId", "categorySlug", "tagName"],
  atMostOne: ["categoryId", "categorySlug"],  // Pick one way to specify category
},
```

Now `{ categoryId: 5, categorySlug: "support" }` fails:

```
Block "featured-topics" at blocks[0]:
At most one of "categoryId", "categorySlug" may be provided, but got 2.
```

### All Available Constraints

| Constraint | When to Use | Example |
|------------|-------------|---------|
| `atLeastOne` | User must provide at least one option | `["categoryId", "tagName"]` |
| `exactlyOne` | Mutually exclusive, one required | `["id", "slug"]` |
| `atMostOne` | Mutually exclusive, all optional | `["startDate", "daysAgo"]` |
| `allOrNone` | Args that only make sense together | `["width", "height"]` |
| `requires` | One arg depends on another | `{ endDate: "startDate" }` |

---

## Part 3: Custom Validation

Some rules can't be expressed with constraints. For example: "if layout is `compact`, max count is 10."

Add a `validate` function:

```gjs
@block("theme:my-theme:featured-topics", {
  args: {
    count: { type: "number", default: 5, min: 1, max: 20, integer: true },
    categoryId: { type: "number", integer: true },
    categorySlug: { type: "string" },
    tagName: { type: "string" },
    title: { type: "string", default: "Featured Topics" },
    layout: { type: "string", enum: ["list", "grid", "compact"], default: "list" },
  },
  constraints: {
    atLeastOne: ["categoryId", "categorySlug", "tagName"],
    atMostOne: ["categoryId", "categorySlug"],
  },
  validate(args) {
    if (args.layout === "compact" && args.count > 10) {
      return "Compact layout supports a maximum of 10 items";
    }
    // Return undefined/null if valid
    // Return string for one error
    // Return array for multiple errors
  },
})
```

Custom validation runs *after* type checking and constraints pass.

---

## Part 4: Outlet Restrictions

Our featured topics block is designed for main content areas—it wouldn't look right in a narrow sidebar. Let's enforce that:

```gjs
@block("theme:my-theme:featured-topics", {
  args: { /* ... */ },
  constraints: { /* ... */ },
  validate(args) { /* ... */ },

  // Only allow in these outlets
  allowedOutlets: ["homepage-*", "discovery-*", "category-*"],

  // Never allow in these
  deniedOutlets: ["sidebar-*", "header-*"],
})
```

Patterns use glob syntax:
- `"homepage-blocks"` - Exact match
- `"homepage-*"` - Wildcard
- `"{sidebar,footer}-*"` - Either sidebar-* or footer-*

If someone tries to use this block in `sidebar-right`, they get:

```
Block "featured-topics" cannot render in outlet "sidebar-right":
Denied by deniedOutlets pattern "sidebar-*".
```

---

## Part 5: The Complete Block

Here's our full `FeaturedTopics` block with everything we've built:

```gjs
// blocks/featured-topics.gjs
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/blocks";

@block("theme:my-theme:featured-topics", {
  description: "Displays featured topics from a category or tag",

  args: {
    count: {
      type: "number",
      default: 5,
      min: 1,
      max: 20,
      integer: true,
    },
    categoryId: { type: "number", integer: true },
    categorySlug: { type: "string" },
    tagName: { type: "string" },
    title: { type: "string", default: "Featured Topics" },
    layout: {
      type: "string",
      enum: ["list", "grid", "compact"],
      default: "list",
    },
  },

  constraints: {
    atLeastOne: ["categoryId", "categorySlug", "tagName"],
    atMostOne: ["categoryId", "categorySlug"],
  },

  validate(args) {
    if (args.layout === "compact" && args.count > 10) {
      return "Compact layout supports a maximum of 10 items";
    }
  },

  allowedOutlets: ["homepage-*", "discovery-*", "category-*"],
  deniedOutlets: ["sidebar-*", "header-*"],
})
export default class FeaturedTopics extends Component {
  @service store;

  get topics() {
    // Fetch logic would go here
    return [];
  }

  <template>
    <div class="featured-topics featured-topics--{{@layout}}">
      <h3>{{@title}}</h3>
      {{#each this.topics as |topic|}}
        <div class="featured-topics__item">
          {{topic.title}}
        </div>
      {{else}}
        <p>No featured topics found.</p>
      {{/each}}
    </div>
  </template>
}
```

---

## Part 6: Building a Container Block

Now let's create a `ContentGrid` that arranges multiple blocks in a grid layout. Container blocks can hold children and access metadata about them.

### Basic Container

```gjs
// blocks/content-grid.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

@block("theme:my-theme:content-grid", {
  container: true,  // This is what makes it a container
  description: "Arranges child blocks in a responsive grid",

  args: {
    columns: {
      type: "number",
      default: 3,
      min: 1,
      max: 4,
      integer: true,
    },
    gap: {
      type: "string",
      enum: ["none", "small", "medium", "large"],
      default: "medium",
    },
  },
})
export default class ContentGrid extends Component {
  <template>
    <div class="content-grid content-grid--cols-{{@columns}} content-grid--gap-{{@gap}}">
      {{#each @children key="key" as |child|}}
        <div class="content-grid__cell">
          <child.Component />
        </div>
      {{/each}}
    </div>
  </template>
}
```

**Key points:**
- `container: true` enables the `children` property
- `@children` is an array of processed, renderable child blocks
- Always use `key="key"` for stable rendering
- `<child.Component />` renders each child

### Using the Container

```javascript
api.renderBlocks("homepage-blocks", [
  {
    block: ContentGrid,
    args: { columns: 3, gap: "medium" },
    children: [
      { block: FeaturedTopics, args: { categorySlug: "announcements", count: 3 } },
      { block: FeaturedTopics, args: { tagName: "featured", count: 3 } },
      { block: RecentActivity },
    ],
  },
]);
```

### Container with Required Child Metadata

Sometimes containers need information from their children. A tabs container needs tab names. A card grid might want icons. Use `childArgs` to require this:

```gjs
@block("theme:my-theme:icon-grid", {
  container: true,
  description: "Grid where each child has an icon and label",

  childArgs: {
    icon: { type: "string", required: true },
    label: { type: "string", required: true },
    color: { type: "string", default: "primary" },
  },
})
export default class IconGrid extends Component {
  <template>
    <div class="icon-grid">
      {{#each @children key="key" as |child|}}
        <div class="icon-grid__item icon-grid__item--{{child.containerArgs.color}}">
          <span class="icon-grid__icon">{{icon child.containerArgs.icon}}</span>
          <span class="icon-grid__label">{{child.containerArgs.label}}</span>
          <child.Component />
        </div>
      {{/each}}
    </div>
  </template>
}
```

Children provide metadata via `containerArgs`:

```javascript
{
  block: IconGrid,
  children: [
    {
      block: StatsWidget,
      containerArgs: { icon: "chart-line", label: "Statistics" },
    },
    {
      block: RecentTopics,
      containerArgs: { icon: "comments", label: "Discussions", color: "secondary" },
    },
  ],
}
```

Use `unique: true` on childArgs to prevent duplicates:

```gjs
childArgs: {
  id: { type: "string", required: true, unique: true },  // Each child needs unique id
}
```

---

## Part 7: Creating a Custom Condition

Built-in conditions cover common cases, but sometimes you need custom logic. Let's create a `subscription` condition for premium content.

### Define the Condition

```javascript
// blocks/conditions/subscription.js
import { service } from "@ember/service";
import { BlockCondition, blockCondition } from "discourse/blocks/conditions";

@blockCondition({
  type: "theme:my-theme:subscription",
  args: {
    plan: {
      type: "string",
      enum: ["free", "basic", "premium", "enterprise"],
      required: true,
    },
    minPlan: { type: "boolean", default: false },
  },
})
export default class SubscriptionCondition extends BlockCondition {
  @service currentUser;
  @service subscription; // Your custom service

  // Plan hierarchy for minPlan comparisons
  planLevels = { free: 0, basic: 1, premium: 2, enterprise: 3 };

  evaluate(args, context) {
    const userPlan = this.subscription.currentPlan || "free";
    const userLevel = this.planLevels[userPlan];
    const requiredLevel = this.planLevels[args.plan];

    if (args.minPlan) {
      // User's plan must be at least the required level
      return userLevel >= requiredLevel;
    } else {
      // Exact match
      return userPlan === args.plan;
    }
  }
}
```

### Register the Condition

Conditions must be registered in a pre-initializer:

```javascript
// pre-initializers/register-conditions.js
import { withPluginApi } from "discourse/lib/plugin-api";
import SubscriptionCondition from "../blocks/conditions/subscription";

export default {
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlockConditionType(SubscriptionCondition);
    });
  },
};
```

### Use the Condition

```javascript
api.renderBlocks("dashboard", [
  // Basic users and above see this
  {
    block: BasicDashboard,
    conditions: { type: "theme:my-theme:subscription", plan: "basic", minPlan: true },
  },

  // Only premium users see this
  {
    block: PremiumFeatures,
    conditions: { type: "theme:my-theme:subscription", plan: "premium", minPlan: true },
  },

  // Combine with other conditions: premium AND admin
  {
    block: AdminPremiumTools,
    conditions: [
      { type: "theme:my-theme:subscription", plan: "premium", minPlan: true },
      { type: "user", admin: true },
    ],
  },
]);
```

### The evaluate() Contract

Your `evaluate` method must:
- **Return synchronously** - No async/await. If you need async data, fetch it elsewhere and pass via outlet args.
- **Return a boolean** - `true` to show the block, `false` to hide it.

```javascript
// ❌ Won't work - can't use await
evaluate(args) {
  const data = await fetch('/api/subscription');
  return data.plan === args.plan;
}

// ✅ Use data passed through outlet args
evaluate(args, context) {
  return context.outletArgs.subscription?.plan === args.plan;
}
```

---

## Part 8: Registration

### When to Register Blocks

Registration is required when:
- Referencing blocks by string name: `{ block: "theme:my-theme:featured-topics" }`
- Providing blocks for others to use (plugin blocks for themes)

Registration is optional when:
- Passing classes directly: `{ block: FeaturedTopics }`

```javascript
// pre-initializers/register-blocks.js
import { withPluginApi } from "discourse/lib/plugin-api";
import FeaturedTopics from "../blocks/featured-topics";
import ContentGrid from "../blocks/content-grid";

export default {
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(FeaturedTopics);
      api.registerBlock(ContentGrid);
    });
  },
};
```

### Lazy Loading

To use lazy registration to split the code:

```javascript
api.registerBlock(
  "theme:my-theme:heavy-analytics",
  () => import("../blocks/heavy-analytics")
);
```

The block code only loads when actually rendered.

---

## Part 9: Testing Your Blocks

Test that your blocks render correctly with valid configuration. Arg validation is handled by the framework—you don't need to test that invalid args throw errors.

### Testing Block Rendering

```gjs
import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Block | featured-topics", function (hooks) {
  setupRenderingTest(hooks);

  test("renders with valid args", async function (assert) {
    @block("test-featured", {
      args: {
        title: { type: "string" },
        count: { type: "number", default: 5 },
      },
    })
    class TestFeatured extends Component {
      <template>
        <div class="test-featured">
          <h3>{{@title}}</h3>
          <span class="count">{{@count}} items</span>
        </div>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: TestFeatured, args: { title: "Featured" } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".test-featured h3").hasText("Featured");
    assert.dom(".test-featured .count").hasText("5 items"); // Default applied
  });

  test("respects conditions", async function (assert) {
    @block("conditional-block")
    class ConditionalBlock extends Component {
      <template><div class="conditional">Visible</div></template>
    }

    withPluginApi((api) =>
      api.renderBlocks("sidebar-blocks", [
        {
          block: ConditionalBlock,
          conditions: { type: "user", admin: true }, // Will fail for non-admin
        },
      ])
    );

    await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

    // Block hidden because test user isn't admin
    assert.dom(".conditional").doesNotExist();
  });
});
```

### Testing Custom Conditions

```javascript
import { getOwner, setOwner } from "@ember/owner";
import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import SubscriptionCondition from "my-theme/blocks/conditions/subscription";

module("Unit | Condition | subscription", function (hooks) {
  setupTest(hooks);

  test("minPlan: true allows higher plans", function (assert) {
    const condition = new SubscriptionCondition();
    setOwner(condition, getOwner(this));

    // Mock the subscription service
    condition.subscription = { currentPlan: "premium" };

    // Premium user should see basic+ content
    assert.true(
      condition.evaluate({ plan: "basic", minPlan: true }, {})
    );

    // Premium user should see premium+ content
    assert.true(
      condition.evaluate({ plan: "premium", minPlan: true }, {})
    );

    // Premium user should NOT see enterprise+ content
    assert.false(
      condition.evaluate({ plan: "enterprise", minPlan: true }, {})
    );
  });
});
```

---

## Part 10: Tutorials

These tutorials demonstrate patterns not covered in the main guide.

### Tutorial 1: Category-Specific Information Panels

Build an information panel system that shows different content based on which category the user is browsing. This example assumes a hypothetical `category-sidebar-blocks` outlet.

**Step 1: Create a reusable info panel block**

```javascript
// themes/my-theme/javascripts/discourse/blocks/info-panel.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import icon from "discourse/helpers/d-icon";

@block("theme:my-theme:info-panel", {
  description: "An information panel with title, content, and optional icon",
  args: {
    title: { type: "string", required: true },
    content: { type: "string", required: true },
    icon: { type: "string" },
    variant: { type: "string", default: "default", enum: ["default", "highlight", "warning"] },
  },
})
export default class InfoPanel extends Component {
  <template>
    <aside class="info-panel info-panel--{{@variant}}">
      <header class="info-panel__header">
        {{#if @icon}}
          {{icon @icon}}
        {{/if}}
        <h3 class="info-panel__title">{{@title}}</h3>
      </header>
      <div class="info-panel__content">
        {{@content}}
      </div>
    </aside>
  </template>
}
```

**Step 2: Configure panels with prioritized fallback**

The `head` container renders only its first visible child—perfect for "if X, else if Y, else Z" logic:

```javascript
// themes/my-theme/javascripts/discourse/api-initializers/category-panels.js
import { apiInitializer } from "discourse/lib/api";
import InfoPanel from "../blocks/info-panel";

export default apiInitializer((api) => {
  api.renderBlocks("category-sidebar-blocks", [
    {
      block: "head",
      children: [
        // Priority 1: Support category - show help resources
        {
          block: InfoPanel,
          args: {
            title: "Need Help?",
            content: "Check our FAQ or contact support for assistance.",
            icon: "question-circle",
            variant: "highlight",
          },
          conditions: [
            { type: "route", pages: ["CATEGORY_PAGES"], params: { categorySlug: "support" } },
          ],
        },

        // Priority 2: Announcements category - show posting guidelines (staff only)
        {
          block: InfoPanel,
          args: {
            title: "Posting Guidelines",
            content: "Only staff can create announcements. Use clear, concise titles.",
            icon: "bullhorn",
            variant: "warning",
          },
          conditions: [
            { type: "route", pages: ["CATEGORY_PAGES"], params: { categorySlug: "announcements" } },
            { type: "user", staff: true },
          ],
        },

        // Priority 3: Development categories - show API docs link
        {
          block: InfoPanel,
          args: {
            title: "Developer Resources",
            content: "Visit our API documentation for technical details.",
            icon: "code",
          },
          conditions: {
            type: "route",
            pages: ["CATEGORY_PAGES"],
            params: { any: [{ categorySlug: "dev" }, { categorySlug: "plugins" }, { categorySlug: "themes" }] },
          },
        },

        // Default fallback: show community welcome (no conditions = always matches)
        {
          block: InfoPanel,
          args: {
            title: "Welcome!",
            content: "Be respectful and help each other learn.",
            icon: "heart",
          },
        },
      ],
    },
  ]);
});
```

**Step 3: Add a conditional panel using outlet args**

```javascript
api.renderBlocks("category-sidebar-blocks", [
  // Rules panel: shows above the category panel when rules exist
  {
    block: InfoPanel,
    args: {
      title: "Category Rules",
      content: "Please read the pinned topics before posting.",
      icon: "list-check",
      variant: "warning",
    },
    conditions: {
      type: "outlet-arg",
      path: "category.custom_fields.has_rules",
      value: true,
    },
  },

  // Category-specific panel (head from Step 2)
  {
    block: "head",
    children: [
      // ... same children as Step 2
    ],
  },
]);
```

---

### Tutorial 2: Theme Dashboard from Plugin Blocks

Build a community dashboard where plugins register blocks and the theme composes them.

**Plugin A: Analytics Plugin**

```javascript
// plugins/discourse-analytics/assets/javascripts/discourse/blocks/stats-panel.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

@block("discourse-analytics:stats-panel", {
  description: "Displays community statistics",
  args: {
    title: { type: "string", default: "Community Stats" },
    showGrowth: { type: "boolean", default: true },
  },
})
export default class StatsPanel extends Component {
  <template>
    <div class="stats-panel">
      <h3 class="stats-panel__title">{{@title}}</h3>
      <ul class="stats-panel__list">
        <li>Total Users: {{@outletArgs.stats.totalUsers}}</li>
        <li>Posts Today: {{@outletArgs.stats.postsToday}}</li>
        {{#if @showGrowth}}
          <li>Growth: {{@outletArgs.stats.growthPercent}}%</li>
        {{/if}}
      </ul>
    </div>
  </template>
}
```

**Plugin B: Tasks Plugin**

```javascript
// plugins/discourse-tasks/assets/javascripts/discourse/blocks/task-list.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

@block("discourse-tasks:task-list", {
  description: "Shows user's pending tasks",
  args: {
    limit: { type: "number", default: 5 },
    showCompleted: { type: "boolean", default: false },
  },
})
export default class TaskList extends Component {
  <template>
    <div class="task-list">
      <h3 class="task-list__title">My Tasks</h3>
      <ul class="task-list__items">
        {{#each @outletArgs.tasks as |task|}}
          <li class="task-list__item">{{task.title}}</li>
        {{/each}}
      </ul>
    </div>
  </template>
}
```

**Theme: Composing the Dashboard**

```javascript
// themes/my-dashboard-theme/javascripts/discourse/api-initializers/dashboard-layout.js
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.renderBlocks("community-dashboard", [
    // Stats for everyone (optional - plugin may not be installed)
    {
      block: "discourse-analytics:stats-panel?",
      args: { title: "Our Community", showGrowth: true },
    },

    // Tasks only for logged-in users (optional)
    {
      block: "discourse-tasks:task-list?",
      args: { limit: 5 },
      conditions: { type: "user", loggedIn: true },
    },

    // Leaderboard only on desktop (optional)
    {
      block: "discourse-gamification:leaderboard?",
      args: { count: 5, period: "month" },
      conditions: { type: "viewport", min: "md" },
    },
  ]);
});
```

> :exclamation: The `?` suffix marks blocks as **optional**. If the plugin isn't installed, the block silently skips instead of throwing an error.

---

## Quick Reference

### @block() Decorator Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `container` | `boolean` | `false` | Enables `@children` prop for holding child blocks |
| `description` | `string` | `""` | Human-readable description for dev tools |
| `args` | `object` | `null` | Arg schema definitions (see Part 1) |
| `constraints` | `object` | `null` | Cross-arg validation rules (see Part 2) |
| `validate` | `function` | `null` | Custom validation function (see Part 3) |
| `allowedOutlets` | `string[]` | `null` | Glob patterns for allowed outlets |
| `deniedOutlets` | `string[]` | `null` | Glob patterns for denied outlets |
| `childArgs` | `object` | `null` | Required child metadata schema (containers only) |
| `classNames` | `string`, `string[]`, or `function` | `null` | Custom CSS classes added to wrapper |

### @blockCondition() Decorator Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `type` | `string` | (required) | Unique condition identifier (e.g., `"theme:my-theme:subscription"`) |
| `args` | `object` | `{}` | Arg schema (same format as block args) |
| `constraints` | `object` | `null` | Cross-arg constraints |
| `validate` | `function` | `null` | Custom validation function |
| `sourceType` | `string` | `"none"` | How `source` param works: `"none"`, `"outletArgs"`, or `"object"` |

### Block Entry Properties

| Property | Type | Description |
|----------|------|-------------|
| `block` | `class` or `string` | The block to render (class reference or registered name) |
| `args` | `object` | Values passed to the block's declared args |
| `conditions` | `object` or `array` | When to show this block (see Getting Started guide) |
| `id` | `string` | Optional ID for CSS targeting (generates BEM class) |
| `children` | `array` | Child entries (container blocks only) |
| `containerArgs` | `object` | Metadata for parent container's `childArgs` |

---

## Next Steps

- **[Concepts](block-api-01-concepts.md)** - Deep conceptual understanding
- **[Reference](block-api-06-reference.md)** - Complete API reference
- **[Internals](block-api-05-internals.md)** - How it works under the hood
