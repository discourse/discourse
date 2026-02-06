# Block API: Core Concepts

> **Navigation:** [Getting Started](block-api-getting-started.md) | **Concepts** | [Architecture](block-api-02-architecture.md) | [Conditions](block-api-03-conditions.md) | [Runtime](block-api-04-runtime.md) | [Internals](block-api-05-internals.md) | [Reference](block-api-06-reference.md) | [Authoring](block-api-authoring.md)

---

## What Are Blocks?

The Blocks API provides a structured approach to UI extension points. It offers:

- **Declarative conditions** that determine when content appears
- **A central registry** of what's been registered and where
- **Coordinated rendering** with predictable ordering
- **Validated args** that catch typos at boot time, not runtime
- **Rich developer tooling** for debugging visibility issues

It's designed for the common cases—adding content to designated areas with conditional visibility, validation, and debugging tools.

### What Blocks Are For

Blocks are designed for **structured layout areas**—regions where you want to compose multiple panels, cards, or content sections with validation, conditions, and theme control. Think homepage content grids, sidebar panel areas, dashboard panels, category page customizations, and discovery page sections. These are places where multiple contributors (plugins, themes) can provide content that a theme orchestrates into a cohesive layout.

**When blocks might not fit:** Components that need to bypass the block layout constraints or condition system, or highly custom interactive features requiring complete control over rendering, are better served by plugin outlets.

**Blocks are NOT intended for** small UI additions like badges, icons, or buttons; avatar modifications; minor UI tweaks scattered throughout the app; or places where the "composed layout" model doesn't fit. A page might use blocks for its main content layout while using plugin outlets for smaller additions elsewhere.

### Limitations

Before diving in, understand what the Blocks API *doesn't* do:

| Limitation | Description |
|------------|-------------|
| **One layout per outlet** | A block outlet has a single owner. Calling `renderBlocks()` twice for the same outlet raises an error—no merging or appending. |
| **No runtime reconfiguration** | Outlet layouts are set at boot time during initializers. You can't add or remove blocks after the application starts. Conditions handle dynamic visibility, but the set of *possible* blocks is fixed. |
| **Synchronous conditions** | The `evaluate()` method must return a boolean immediately. You can't await an API call to determine visibility. |
| **No partial re-evaluation** | When conditions depend on reactive state, the entire block tree re-evaluates. For outlets with many blocks or complex conditions, this can impact performance. |
| **Name length limit** | Block and outlet names cannot exceed 100 characters (including the full namespaced name). |
| **Nesting depth limit** | Block layouts cannot nest deeper than 20 levels. |

These constraints are intentional trade-offs for simplicity and predictability. For custom solutions that don't fit the block model—complex interactive components, entirely custom layouts, or cases requiring multiple independent contributors—plugin outlets remain available.

---

## Think of It Like Furniture

Think of the Blocks API like an interior design system with modular furniture.

| Concept | Analogy | Technical Reality |
|---------|---------|-------------------|
| **Outlets** | Rooms—designated spaces with walls and floor space | Designated UI locations where blocks can render (`homepage-blocks`, `sidebar-blocks`) |
| **Blocks** | Furniture modules—standardized units with defined specs | Components with a name, defined args schema, and validation |
| **Registry** | Product catalog—what's available before shopping | List of all registered blocks, checked before layout configuration |
| **Conditions** | Assembly requirements—"mount if wall is load-bearing" | Visibility rules evaluated at render time |
| **Container blocks** | Units with compartments—furniture holding other furniture | Blocks that render child blocks in a structured arrangement |
| **Plugins** | Third-party manufacturers making compatible pieces | Providers that register blocks without knowing where they'll be used |
| **Theme calling renderBlocks()** | Interior designer deciding what goes where | Single owner configuring the outlet layout |

This mental model explains the API's design decisions:

- **Why must blocks be registered before `renderBlocks()`?** The catalog must exist before the designer starts shopping.
- **Why can't blocks render outside outlets?** Furniture needs a room—you can't place it in thin air.
- **Why are conditions evaluated at render time?** Assembly requirements are checked when placing furniture, not when it was manufactured.
- **Why can multiple plugins provide blocks without conflict?** Manufacturers don't fight over shelf space—they just make products. The designer decides what goes where.
- **Why can only one caller configure an outlet?** One designer per room. Two designers with different visions for the same space creates chaos.

---

## Your First Block

Start with the absolute minimum—a block that renders static content:

```javascript
// themes/my-theme/javascripts/discourse/blocks/welcome-banner.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

@block("theme:my-theme:welcome-banner")
export default class WelcomeBanner extends Component {
  <template>
    <div class="welcome-banner">
      <h2>Welcome to our community!</h2>
    </div>
  </template>
}
```

```javascript
// themes/my-theme/javascripts/discourse/pre-initializers/register-blocks.js
import { withPluginApi } from "discourse/lib/plugin-api";
import WelcomeBanner from "../blocks/welcome-banner";

export default {
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(WelcomeBanner);
    });
  },
};
```

```javascript
// themes/my-theme/javascripts/discourse/api-initializers/configure-blocks.js
import { apiInitializer } from "discourse/lib/api";
import WelcomeBanner from "../blocks/welcome-banner";

export default apiInitializer((api) => {
  api.renderBlocks("homepage-blocks", [
    { block: WelcomeBanner },
  ]);
});
```

That's it. The block, registration, and layout configuration. Each object in the layout array is a **block entry**—it tells the system which block to render and how to configure it.

**Adding args:**

```javascript
// blocks/welcome-banner.gjs
@block("theme:my-theme:welcome-banner", {
  args: {
    message: { type: "string", required: true },
  },
})
export default class WelcomeBanner extends Component {
  <template>
    <div class="welcome-banner">
      <h2>{{@message}}</h2>
    </div>
  </template>
}
```

```javascript
// api-initializers/configure-blocks.js
api.renderBlocks("homepage-blocks", [
  {
    block: WelcomeBanner,
    args: { message: "Welcome to our community!" },
  },
]);
```

**Adding conditions:**

```javascript
api.renderBlocks("homepage-blocks", [
  {
    block: WelcomeBanner,
    args: { message: "Welcome back!" },
    conditions: { type: "user", loggedIn: true },
  },
]);
```

For multiple conditions (AND logic), use an array:

```javascript
conditions: [
  { type: "user", loggedIn: true },
  { type: "user", minTrustLevel: 2 },
]
```

---

## Block Entry Properties

Each block entry tells the system what to render and how to configure it. Think of it as filling out an order form: specify which block you want (`block`), customize it with data (`args`), and set visibility rules (`conditions`).

| Property | Required | Purpose |
|----------|----------|---------|
| `block` | Yes | Which block to render (component class or registered string name) |
| `args` | No | Configuration data passed to the component via `@args` |
| `conditions` | No | Visibility rules—when omitted, the block always renders |
| `id` | No | Identifier for CSS targeting and debugging |
| `children` | No | Nested blocks for container blocks |
| `containerArgs` | No | Metadata a child provides to its parent container |

---

## What's Inside a Block

Blocks can do more than just render with args. Let's look at all the options available in the `@block` decorator.

### Complete Example

The following example uses every available option—not because you'd use them all at once, but so you can see where each capability lives:

```javascript
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/blocks";

@block("theme:my-theme:hero-banner", {
  // (A) Container mode - can this block contain child blocks?
  container: false,

  // (B) Human-readable description for documentation and dev tools
  description: "A hero banner with customizable title, subtitle, and call-to-action",

  // (C) Arguments schema - validates args at registration time
  args: {
    title: { type: "string", required: true },
    subtitle: { type: "string", default: "Welcome to our community" },
    ctaText: { type: "string", default: "Get Started" },
    ctaUrl: { type: "string" },
    showImage: { type: "boolean", default: true },
    featuredTags: { type: "array", itemType: "string" },
    categoryId: { type: "number", min: 1, integer: true },
    tagName: { type: "string" },
    maxItems: { type: "number", min: 1, max: 100, default: 10 },
  },

  // (D) Cross-arg constraints - validation rules across multiple args
  constraints: {
    atLeastOne: ["categoryId", "tagName"],
  },

  // (E) Custom validation - bespoke validation logic
  validate(args) {
    if (args.ctaText && !args.ctaUrl) {
      return "ctaUrl is required when ctaText is provided";
    }
  },

  // (F) Outlet restrictions - where can this block render?
  allowedOutlets: ["homepage-blocks", "hero-*"],

  // (G) Outlet exclusions - where should this block never render?
  deniedOutlets: ["sidebar-*"],

  // (H) Child args schema - metadata children must provide (container blocks only)
  // childArgs: {
  //   name: { type: "string", required: true, unique: true },
  //   icon: { type: "string" },
  // },
})
export default class HeroBanner extends Component {
  @service router;

  get ctaHref() {
    return this.args.ctaUrl || "/";
  }

  <template>
    <div class="hero-banner">
      <h1>{{@title}}</h1>
      <p>{{@subtitle}}</p>
      {{#if @showImage}}
        <div class="hero-banner__image">
          {{! Image content }}
        </div>
      {{/if}}
      <a href={{this.ctaHref}} class="hero-banner__cta">
        {{@ctaText}}
      </a>
    </div>
  </template>
}
```

> :bulb: Don't worry about `childArgs` and `containerArgs` yet—they're for container blocks, covered in section (H) below.

---

### (A) Block Name

Every block needs a unique name. The system uses namespacing to prevent collisions:

| Format | Source | Example |
|--------|--------|---------|
| `block-name` | Core Discourse | `group`, `head` |
| `plugin:block-name` | Plugins | `chat:message-panel` |
| `theme:namespace:block-name` | Themes | `theme:tactile:hero-banner` |

Two themes can both define "banner" blocks because they're namespaced differently: `theme:tactile:banner` vs `theme:starter:banner`.

**What happens if you omit the namespace?** You get an error:
- Plugins: `Plugin blocks must use the "namespace:block-name" format.`
- Themes: `Theme blocks must use the "theme:namespace:block-name" format.`

Only core Discourse can use the unnamespaced `block-name` format.

### (A.1) Container Mode

```javascript
container: false,
```

Container blocks can hold child blocks. Non-container blocks cannot. This is enforced at validation time—specifying `children` for a non-container block causes an error.

**Container blocks have different responsibilities:**
- Receive `children` as a processed array of renderable components
- Iterate and render their children in their template
- Inherit an implicit condition: "only render if I have visible children"

**Default:** `false` (non-container)

### (A.2) CSS Classes

Blocks receive automatic BEM-style CSS classes:

| Element | Class Pattern | Example |
|---------|---------------|---------|
| Block wrapper | `{outletName}__block` | `homepage-blocks__block` |
| Block with id | `{outletName}__block--{id}` | `homepage-blocks__block--featured` |
| Container wrapper | `{outletName}__block-container` | `homepage-blocks__block-container` |
| Container with id | `{outletName}__block-container--{id}` | `homepage-blocks__block-container--dashboard` |

Use these classes to style blocks at different levels:
- `{outletName}__block` - All blocks in a specific outlet
- `{outletName}__block--{id}` - Specific block by id

### (B) Description

```javascript
description: "A hero banner with customizable title, subtitle, and call-to-action",
```

Human-readable text for documentation and dev tools. Optional but recommended for discoverability.

### (C) Args Schema

```javascript
args: {
  title: { type: "string", required: true },
  subtitle: { type: "string", default: "Welcome to our community" },
}
```

The args schema serves three purposes:

1. **Validation at registration time.** Typos like `{ titel: "..." }` get immediate errors with suggestions: `Unknown arg "titel" (did you mean "title"?)`
2. **Default values.** If `subtitle` isn't provided, it defaults to the specified value.
3. **Documentation.** Dev tools can display what arguments a block accepts.

> **Important:** If your block accepts args, you must declare them in the schema. Undeclared args are rejected.

**Arg Types and Constraints:**

| Type | Additional Properties |
|------|----------------------|
| `string` | `minLength`, `maxLength`, `pattern`, `enum` |
| `number` | `min`, `max`, `integer`, `enum` |
| `boolean` | — |
| `array` | `itemType`, `itemEnum`, `minLength`, `maxLength` |
| `object` | `properties`, `instanceOf`, `instanceOfName` |

**Examples:**

```javascript
args: {
  // String with length constraints
  title: { type: "string", minLength: 1, maxLength: 100 },

  // String with enum (dropdown-like)
  size: { type: "string", enum: ["small", "medium", "large"] },

  // Number with range and integer constraint
  page: { type: "number", min: 1, integer: true },

  // Array with length constraints
  tags: { type: "array", itemType: "string", minLength: 1, maxLength: 10 },

  // Object arg (e.g., passing an Ember service or model)
  category: { type: "object", instanceOf: Category, instanceOfName: "Category" },
}
```

> :bulb: **Tip:** Use `required` OR `default`, not both—an arg with a default is never missing.

### (D) Constraints

For validation rules spanning multiple arguments:

| Constraint | Meaning | Example |
|------------|---------|---------|
| `atLeastOne` | At least one arg must be provided | `atLeastOne: ["id", "tag"]` |
| `exactlyOne` | Exactly one arg must be provided | `exactlyOne: ["id", "tag"]` |
| `allOrNone` | Either all are provided or none | `allOrNone: ["width", "height"]` |
| `atMostOne` | At most one arg may be provided | `atMostOne: ["id", "tag"]` |
| `requires` | Dependent arg requires another | `requires: { endDate: "startDate" }` |

**Error messages:**

```
Block "featured-list": at least one of "id", "tag" must be provided.
Block "featured-list": exactly one of "id", "tag" must be provided, but got 2.
Block "featured-list": args "width", "height" must be provided together or not at all.
Block "featured-list": arg "endDate" requires "startDate" to also be provided.
```

### (E) Custom Validation

```javascript
validate(args) {
  if (args.min !== undefined && args.max !== undefined && args.min > args.max) {
    return "min must be less than or equal to max";
  }
}
```

For validation logic that can't be expressed declaratively. Returns:
- `undefined` or `null` if valid
- A `string` error message if invalid
- An `array` of error messages for multiple issues

Runs after declarative constraints pass.

### (F) Allowed Outlets

```javascript
allowedOutlets: ["homepage-blocks", "hero-*"],
```

Restricts where this block can render using glob patterns:
- `"homepage-blocks"` - Exact match
- `"hero-*"` - Wildcard (matches `hero-left`, `hero-right`, etc.)
- `"{sidebar,footer}-*"` - Brace expansion

**What if omitted?** The block can render in any outlet.

### (G) Denied Outlets

```javascript
deniedOutlets: ["sidebar-*"],
```

Prevents the block from rendering in specific outlets. Same glob syntax as `allowedOutlets`.

**Conflict detection:** If a pattern appears in both `allowedOutlets` and `deniedOutlets`, you get an error at decoration time.

### (H) Child Args Schema

**Only for container blocks.** Defines metadata that child blocks must provide via `containerArgs`:

```javascript
@block("my-plugin:tabs-container", {
  container: true,
  childArgs: {
    name: { type: "string", required: true, unique: true },
    icon: { type: "string" },
  },
})
```

Children provide this metadata in the layout config:

```javascript
api.renderBlocks("my-outlet", [
  {
    block: TabsContainer,
    children: [
      {
        block: TabPanel,
        args: { title: "Settings" },
        containerArgs: { name: "settings", icon: "cog" }
      },
      {
        block: TabPanel,
        args: { title: "Profile" },
        containerArgs: { name: "profile", icon: "user" }
      },
    ]
  }
])
```

The container accesses metadata via `this.children`:

```javascript
// In the container component - ALWAYS use key="key" for stable rendering
{{#each this.children key="key" as |child|}}
  <button data-tab={{child.containerArgs.name}}>
    {{#if child.containerArgs.icon}}
      {{icon child.containerArgs.icon}}
    {{/if}}
  </button>
{{/each}}
```

> :exclamation: **Important:** Always use `key="key"` when iterating over `this.children`. Each child has a unique `key` property that ensures stable rendering.

**The `unique` property:** Enforces uniqueness across sibling children:

```
Duplicate value "settings" for containerArgs.name in children of "tabs-container".
Found at children[0] and children[2].
```

---

## From Code to Screen

Understanding when things happen helps debug issues. The journey happens in two phases:

### Boot Time

1. **Pre-initializers run** — `api.registerBlock()` validates block name, namespace, and decoration, then adds to registry
2. **Custom outlets registered** — `api.registerBlockOutlet()` adds any custom outlets
3. **`freeze-block-registry` initializer runs** — Registers built-in blocks (`group`, `head`) and condition types, then freezes all registries
4. **Api-initializers run** — `api.renderBlocks()` validates layouts: outlet existence, block registration, arg schemas, condition syntax

### Render Time

1. **`<BlockOutlet>` renders** — Retrieves stored layout configuration
2. **Conditions evaluate bottom-up** — Children before parents (container visibility depends on children)
3. **Visible blocks render** — Hidden blocks don't appear (unless debug mode shows ghost placeholders)

**Key insight:** Most validation happens at boot time. Typos in condition types, invalid arg names, unregistered blocks—all surface as errors during boot. But when a condition fails at runtime? The block silently doesn't render (or shows as a ghost in debug mode).

> :bulb: When lazy-loaded blocks are involved (registered with a factory function like `() => import("./my-block")`), schema and constraint validations are deferred until the layout renders for the first time.

---

> **Next:** [Architecture](block-api-02-architecture.md) — The `@block` decorator, `<BlockOutlet>` component, and `renderBlocks()` function
