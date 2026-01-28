# Building with Blocks

----------------------

## 1. How It All Works

### The Problem Being Solved

Plugin outlets have served Discourse well for years, but they have limitations:

- **Duplicated logic.** You handle visibility logic inside connector components, often duplicating checks across multiple connectors.
- **No coordination.** Multiple plugins extending the same outlet have no structured way to order themselves or share context.
- **Template-only extension.** Outlets are places to inject markup, but there's no registry of what's injected or metadata about it.
- **No validation.** Typos in outlet names fail silently. Invalid arguments aren't caught until runtime (if at all).

The Blocks API is a structured alternative for UI extension points that need:
- Declarative, validated conditions that determine when content appears
- A registry of what's been registered and where
- Coordinated rendering with predictable ordering
- Rich developer tooling for debugging visibility issues

It's designed to handle the common cases—adding content to designated areas with conditional visibility, validation, and debugging tools. Plugin outlets remain available for complex scenarios requiring completely custom components that don't fit the block model.

### What Blocks Are For

Blocks are designed for **structured layout areas**—regions where you want to compose multiple panels, cards, or content sections with validation, conditions, and theme control. Think homepage content grids, sidebar panel areas, dashboard panels, category page customizations, and discovery page sections. These are places where you want multiple contributors (plugins, themes) to provide content that a theme can orchestrate into a cohesive layout.

**When blocks might not fit:** Components that need to bypass the block layout constraints or condition system, or highly custom interactive features requiring complete control over rendering, are better served by plugin outlets.

**Blocks are NOT intended for** small UI additions like badges, icons, or buttons; avatar modifications; minor UI tweaks scattered throughout the app; or places where the "composed layout" model simply doesn't fit. For smaller customizations or highly specialized features, plugin outlets remain available. A page might use blocks for its main content layout while using plugin outlets for small additions elsewhere.

### Limitations

Before diving in, understand what the Blocks API *doesn't* do:

- **One layout per outlet.** Unlike plugin outlets where multiple connectors coexist, a block outlet has a single owner. If you call `renderBlocks("homepage-blocks", [...])` twice, the second call raises an error—there's no merging or appending. This means two plugins targeting the same outlet will conflict based on load order. The intended pattern: plugins register blocks, themes call `renderBlocks()` to compose the layout. This separates content (plugins) from presentation (themes).

- **No runtime reconfiguration.** Outlet layouts are set at boot time during initializers. You can't add or remove blocks after the application starts. Conditions (the visibility rules covered in Section 3) handle dynamic visibility, but the set of *possible* blocks is fixed.

- **Conditions are synchronous.** The `evaluate()` method must return a boolean immediately. You can't await an API call to determine visibility. If you need async data, fetch it elsewhere and pass it via outlet args (see Section 2).

- **No partial re-evaluation.** When conditions depend on reactive state, the entire block tree re-evaluates. For outlets with many blocks or complex conditions, this can impact performance.

- **Name length limit.** Block and outlet names cannot exceed 100 characters. This applies to the full namespaced name (e.g., `"theme:my-theme:my-block"`).

- **Nesting depth limit.** Block layouts cannot nest deeper than 20 levels. This prevents stack overflow from deeply nested configurations and typically indicates a design issue if reached.

These constraints are intentional trade-offs for simplicity and predictability. For truly custom solutions that don't fit the block model—complex interactive components, entirely custom layouts, or cases requiring multiple independent contributors—plugin outlets remain available.

So how does all this fit together? What are these blocks all about?

### Think of It Like Furniture

Think of the Blocks API like an interior design system with modular furniture.

**Outlets are rooms.** You can't place a bookshelf floating in mid-air—it needs a room with walls and floor space. Similarly, blocks can only render in outlets, not arbitrary template locations. Each outlet (`homepage-blocks`, `sidebar-blocks`) is a designated space positioned somewhere in the UI, with its own purpose and constraints.

**Blocks are furniture modules.** Think cube shelves, bookcases, dressers—standardized units with defined dimensions, product numbers, and assembly specs. Each block has a name (its product number), a component (its design), and an arg schema (its specifications). You order from the catalog, not invent furniture on the fly.

**The registry is your product catalog.** Before you start designing a room, you need to know what's available. The catalog lists every piece that *could* be used. If you try to specify a product that doesn't exist, you'll know immediately—there's no "close enough" when ordering furniture.

**Conditions are assembly requirements.** "Mount this shelf only if the wall is load-bearing" becomes "render only if user is admin." Requirements are checked when you're actually placing the furniture, not when it was manufactured.

**Container blocks are units with compartments.** A cube shelf holds drawer inserts, doors, or storage boxes—it's furniture that contains other furniture. Container blocks work the same way: they're blocks that hold other blocks in a structured arrangement.

**Plugins are third-party manufacturers.** Different furniture companies make compatible modular pieces following common standards. They don't conflict with each other; they just provide options. Plugins work the same way: they register blocks without knowing where they'll be used, trusting that someone else will compose the final layout.

**The theme is your interior designer.** The designer looks at the catalog, considers each room's purpose, and creates a layout: "cube shelf in the living room, bookcase in the office, skip the dresser entirely." This is `renderBlocks()`. Only one designer controls each room—you don't have two people fighting over the living room layout.

This mental model helps explain the API's design decisions:

- **Why must blocks be registered before `renderBlocks()`?** The catalog must exist before the designer starts shopping.
- **Why can't blocks render outside outlets?** Furniture needs a room—you can't place it in thin air.
- **Why are conditions evaluated at render time?** Assembly requirements are checked when placing furniture, not when it was manufactured.
- **Why can multiple plugins provide blocks without conflict?** Manufacturers don't fight over shelf space—they just make products. The designer decides what goes where.
- **Why can only one caller configure an outlet?** One designer per room. Two designers with different visions for the same space creates chaos.
- **Why are conditions declarative?** Assembly instructions are printed rules, not decisions made up on the spot.
- **Why do blocks appear and disappear based on state?** Just like seasonal furniture displays—what's shown depends on context.

Enough with the furniture—let's look at actual code.

### Your First Block

Start with the absolute minimum—a block that just renders static content:

```javascript
// themes/my-theme/javascripts/discourse/blocks/welcome-banner.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks/block-outlet";

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

To make the message configurable:

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

To show only for logged-in users:

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

Each block entry tells the system what to render and how to configure it. Think of it as filling out an order form: you specify which block you want (`block`), optionally customize it with data (`args`), and set visibility rules (`conditions`). The system handles the rest.

The only required property is `block`—a reference to what you want to render. Everything else adds optional customization. You'll often start with just `block` and `args`, then add `conditions` when you need visibility control. As you get into layout composition, you might use `children` for container blocks and `classNames` for styling specific instances. Here's a quick reference:

| Property | Required | Purpose |
|----------|----------|---------|
| `block` | Yes | Which block to render (component class or registered string name) |
| `args` | No | Configuration data passed to the component via `@args` |
| `conditions` | No | Visibility rules—when omitted, the block always renders |
| `classNames` | No | Extra CSS classes added to the block's wrapper element |
| `children` | No | Nested blocks for container blocks (see subsection (H) below) |
| `containerArgs` | No | Metadata a child provides to its parent container (see subsection (H) below) |

The last two properties—`children` and `containerArgs`—only make sense once you understand container blocks, which we'll cover shortly. For now, let's look at the full anatomy of a block to understand all the options available in the `@block` decorator.

### What's Inside a Block

You've already seen the basics: a name, some args, maybe conditions. But blocks can do much more. Let's build up from what you know, adding capabilities layer by layer—then you'll have a mental map of what's possible when you need it.

**Starting simple: just args validation**

Most blocks start here—you want to accept some configuration and ensure callers provide valid data:

```javascript
@block("theme:my-theme:promo-banner", {
  args: {
    message: { type: "string", required: true },
    linkUrl: { type: "string" },
  },
})
export default class PromoBanner extends Component { ... }
```

That's often enough. But what if you need to ensure `linkUrl` is provided whenever `linkText` is? Or restrict where this block can appear? The `@block` decorator offers additional options for these cases.

**The complete picture**

The following example uses every available option—not because you'd use them all at once, but so you can see where each capability lives. We'll walk through each part, explaining what it does and when you'd actually need it:

```javascript
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/blocks/block-outlet";

@block("theme:my-theme:hero-banner", {
  // (A) Container mode - can this block contain child blocks?
  container: false,

  // (A.1) Custom CSS classes for container wrapper (container blocks only)
  // containerClassNames: "my-custom-class",                   // String form
  // containerClassNames: ["class-one", "class-two"],          // Array form
  // containerClassNames: (args) => `hero-${args.variant}`,    // Function form

  // (B) Human-readable description for documentation and dev tools
  description: "A hero banner with customizable title, subtitle, and call-to-action",

  // (C) Arguments schema - validates args at registration time
  args: {
    title: {
      type: "string",
      required: true
    },
    subtitle: {
      type: "string",
      default: "Welcome to our community"
    },
    ctaText: {
      type: "string",
      default: "Get Started"
    },
    ctaUrl: {
      type: "string"
    },
    showImage: {
      type: "boolean",
      default: true
    },
    featuredTags: {
      type: "array",
      itemType: "string"
    },
    categoryId: { type: "number", min: 1, integer: true },
    tagName: { type: "string" },
    maxItems: { type: "number", min: 1, max: 100, default: 10 },
  },

  // (D) Cross-arg constraints - validation rules across multiple args
  constraints: {
    atLeastOne: ["categoryId", "tagName"],  // At least one must be provided
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

> :bulb: Don't worry about `childArgs` and `containerArgs` yet—they're for container blocks, covered in detail in section (H) below.

Let's examine each part:

#### (A) Block Name: `"theme:my-theme:hero-banner"`

Every block needs a unique name. Since plugins and themes come from many different authors, the system uses namespacing to prevent collisions—think of it like package names in JavaScript (`@company/package`) or Java (`com.company.package`). The namespace tells you where the block came from and ensures that two different themes can both have a "banner" block without conflict.

The format depends on who's providing the block:

| Format | Source | Example |
|--------|--------|---------|
| `block-name` | Core Discourse | `group`, `first-match` |
| `plugin:block-name` | Plugins | `chat:message-panel` |
| `theme:namespace:block-name` | Themes | `theme:tactile:hero-banner` |

Two themes can both define "banner" blocks because they're namespaced differently: `theme:tactile:banner` vs `theme:starter:banner`. Without namespacing, two themes defining a "banner" block would conflict—the second registration raises an error: `Block "banner" is already registered.`

**What happens if you omit it?** You get an error. The system detects your source (plugin or theme) and enforces the naming convention:
- Plugins without namespace: `Plugin blocks must use the "namespace:block-name" format.`
- Themes without namespace: `Theme blocks must use the "theme:namespace:block-name" format.`

Only core Discourse can use unnamespaced `block-name` format.

#### (B) Container Mode

```javascript
container: false,
```

Container blocks can hold child blocks. Non-container blocks cannot. This is enforced at validation time—if you specify `children` in a config for a non-container block, you get an error.

**Why this distinction?** Container blocks have different responsibilities:
- They receive `children` as a processed array of renderable components
- They're responsible for iterating and rendering their children in their template
- They can define custom wrapper classes via `containerClassNames`
- They inherit an implicit condition: "only render if I have visible children"

Non-container blocks, by contrast:
- Cannot hold child blocks
- Cannot use `containerClassNames`

Both container and non-container blocks are wrapped by the system with a `<div>` for consistent BEM-style class naming. BEM (Block, Element, Modifier) is a CSS naming convention that uses double underscores for elements within blocks (`block__element`) and double hyphens for modifiers (`block--modifier`)—it helps keep styles scoped and predictable:

| Block Type | Generated Classes |
|------------|-------------------|
| Non-container | `{outletName}__block`, `block-{name}` |
| Container | `block__{name}`, `{outletName}__{name}` |

The class naming strategy lets you style blocks at different levels of specificity. Use `block-{name}` to style a block wherever it appears; use `{outletName}__block` to style all blocks in a specific outlet; use `{outletName}__{name}` for outlet-specific styling of a particular block type.

**Default:** `false` (non-container)

#### (B.1) Container Class Names

```javascript
containerClassNames: (args) => `block__group-${args.name}`,
```

The `containerClassNames` option allows container blocks to define custom CSS classes for their wrapper element. This is **only valid for container blocks** (`container: true`).

**Three supported formats:**

1. **String** - A single CSS class:
   ```javascript
   containerClassNames: "my-container-class"
   ```

2. **Array** - Multiple CSS classes:
   ```javascript
   containerClassNames: ["container-primary", "container-bordered"]
   ```

3. **Function** - Dynamic classes based on block args:
   ```javascript
   containerClassNames: (args) => `container-${args.variant}`
   ```

**When to use:** Use `containerClassNames` when your container block needs custom styling beyond the standard BEM classes provided by the system. The function form is particularly useful when the class should depend on the block's configuration.

**Real example (based on the built-in `group` block, simplified):**

```javascript
@block("group", {
  container: true,
  args: {
    name: { type: "string", required: true },
  },
  containerClassNames: (args) => `block__group-${args.name}`,
})
```

This generates a dynamic class like `block__group-sidebar` when `name: "sidebar"` is passed.

**Error handling:** If you specify `containerClassNames` on a non-container block, you get an error:
```
Block "my-block": "containerClassNames" is only valid for container blocks (container: true).
```

#### (C) Args Schema

```javascript
args: {
  title: { type: "string", required: true },
  subtitle: { type: "string", default: "Welcome to our community" },
  // ...
}
```

The args schema serves three purposes:

1. **Validation at registration time.** If someone calls `renderBlocks()` with `{ block: HeroBanner, args: { titel: "typo" } }`, they get an immediate error with a suggestion: `Unknown arg "titel" (did you mean "title"?)`

2. **Default values.** If `subtitle` isn't provided, it defaults to "Welcome to our community".

3. **Documentation.** Dev tools can display what arguments a block accepts.

> **Important:** If your block accepts args, you must declare them in the schema. Undeclared args will be rejected.

**The basics**

Every arg needs a `type`—that's the only required property. Add `required: true` when callers must provide a value, or `default` when you want to provide one automatically. (Use one or the other, not both—an arg with a default is never "missing.")

The four types cover most needs: `string` for text, `number` for counts and IDs, `boolean` for flags, and `array` for collections. Arrays can specify an `itemType` to validate each element.

**Adding constraints**

Each type supports additional properties for finer-grained validation. A title might need to be between 1 and 100 characters. A page number should be a positive integer. A size dropdown should only accept specific values. Here's what's available:

| Property | Types | Description |
|----------|-------|-------------|
| `minLength` | `string`, `array` | Minimum length (characters or items) |
| `maxLength` | `string`, `array` | Maximum length (characters or items) |
| `pattern` | `string` | Regex pattern for validation |
| `min` | `number` | Minimum value (inclusive) |
| `max` | `number` | Maximum value (inclusive) |
| `integer` | `number` | Must be a whole number |
| `enum` | `string`, `number` | Restrict to specific values |
| `itemType` | `array` | Type of items (`"string"`, `"number"`, `"boolean"`) |
| `itemEnum` | `array` | Restrict array items to specific values |

**Examples:**
```javascript
args: {
  // String with length constraints
  title: { type: "string", minLength: 1, maxLength: 100 },

  // String with enum (dropdown-like)
  size: { type: "string", enum: ["small", "medium", "large"] },

  // Number with range and integer constraint
  page: { type: "number", min: 1, integer: true },

  // Number with enum (specific values)
  priority: { type: "number", enum: [1, 2, 3, 5, 8] },

  // Array with length constraints
  tags: { type: "array", itemType: "string", minLength: 1, maxLength: 10 },

  // Array with itemEnum (restrict items to specific values)
  categories: { type: "array", itemType: "string", itemEnum: ["news", "blog", "docs"] },
}
```

> :bulb: **Tip:** Use `required` OR `default`, not both—an arg with a default is never missing.

#### (D) Constraints

```javascript
constraints: {
  atLeastOne: ["categoryId", "tagName"],
}
```

Individual arg validation catches type errors and missing required fields, but some rules span multiple arguments. Consider a block that fetches featured content—it needs *either* a category ID *or* a tag name, but at least one. Or a date range picker where providing `endDate` only makes sense if `startDate` is also provided. Constraints express these relationships declaratively.

**Start with the most common case:** You want callers to provide at least one of several options. Use `atLeastOne`:

```javascript
constraints: {
  atLeastOne: ["categoryId", "tagName"],  // Must provide one or both
}
```

**Need mutual exclusion?** When options conflict—like `id` versus `slug` for looking up a resource—use `exactlyOne` (one must be provided, not both) or `atMostOne` (zero or one is fine):

```javascript
constraints: {
  exactlyOne: ["id", "slug"],  // Exactly one required
  atMostOne: ["startDate", "daysAgo"],  // At most one allowed
}
```

**Related arguments that go together?** Use `allOrNone` for pairs like width/height or start/end dates:

```javascript
constraints: {
  allOrNone: ["width", "height"],  // Both or neither
}
```

**One arg depends on another?** Use `requires` when an arg only makes sense with another present:

```javascript
constraints: {
  requires: { endDate: "startDate" },  // endDate needs startDate
}
```

Here's the complete reference:

| Constraint | Meaning | Example |
|------------|---------|---------|
| `atLeastOne` | At least one arg must be provided | `atLeastOne: ["id", "tag"]` |
| `exactlyOne` | Exactly one arg must be provided (mutual exclusion + required) | `exactlyOne: ["id", "tag"]` |
| `allOrNone` | Either all are provided or none | `allOrNone: ["width", "height"]` |
| `atMostOne` | At most one arg may be provided (0 or 1, mutual exclusion) | `atMostOne: ["id", "tag"]` |
| `requires` | If dependent arg is provided, required arg must also be provided | `requires: { endDate: "startDate" }` |

**Error messages:**

```
Block "featured-list": at least one of "id", "tag" must be provided.
Block "featured-list": exactly one of "id", "tag" must be provided, but got 2: "id", "tag".
Block "featured-list": exactly one of "id", "tag" must be provided, but got none.
Block "featured-list": args "width", "height" must be provided together or not at all.
Block "featured-list": at most one of "id", "tag" may be provided, but got 2: "id", "tag".
Block "featured-list": arg "endDate" requires "startDate" to also be provided.
```

**Vacuous constraint detection:** The system detects constraints that are always true or always false due to default values. For example:

- `atLeastOne: ["id", "tag"]` where `id` has a default → always true (error at decoration time)
- `exactlyOne: ["id", "tag"]` where both have defaults → always false (error at decoration time)
- `allOrNone: ["width", "height"]` where only `width` has a default → always false (error at decoration time)

**Incompatible constraints:** Some constraint combinations on the same args are errors:

- `exactlyOne` + `allOrNone` → conflict (XOR vs all-or-nothing)
- `exactlyOne` + `atLeastOne` → redundant (exactlyOne implies atLeastOne)

#### (E) Custom Validation

```javascript
validate(args) {
  if (args.min !== undefined && args.max !== undefined && args.min > args.max) {
    return "min must be less than or equal to max";
  }
}
```

For validation logic that can't be expressed with declarative constraints, use a `validate` function. It receives the args object (with defaults applied) and should return:

- `undefined` or `null` if valid
- A `string` error message if invalid
- An `array` of error messages for multiple issues

The `validate` function runs after declarative constraints pass.

#### (F) Allowed Outlets

```javascript
allowedOutlets: ["homepage-blocks", "hero-*"],
```

Restricts where this block can render. The patterns use "glob" syntax—a wildcard matching system common in file paths and shell commands. The `*` matches any characters, and `{a,b}` matches either `a` or `b`. We use the [picomatch](https://github.com/micromatch/picomatch) library under the hood:

- `"homepage-blocks"` - Exact match
- `"hero-*"` - Wildcard (matches `hero-left`, `hero-right`, etc.)
- `"{sidebar,footer}-*"` - Brace expansion (matches `sidebar-*` OR `footer-*`)

**What happens if you omit it?** The block can render in any outlet.

**What if someone tries to use this block in `sidebar-blocks`?** They get a validation error: `Block "theme:my-theme:hero-banner" cannot be rendered in outlet "sidebar-blocks": outlet "sidebar-blocks" does not match any allowedOutlets pattern.`

#### (G) Denied Outlets

```javascript
deniedOutlets: ["sidebar-*"],
```

Prevents the block from rendering in specific outlets. Same glob syntax as `allowedOutlets`.

**Conflict detection:** If a pattern appears in both `allowedOutlets` and `deniedOutlets`, you get an error at decoration time (when the class is defined), not at runtime.

#### (H) Child Args Schema

```javascript
childArgs: {
  name: { type: "string", required: true, unique: true },
  icon: { type: "string" },
}
```

**Only for container blocks.** Defines metadata that child blocks must provide via `containerArgs` when configured as children of this container.

**Why this exists?** Container blocks often need to know something about their children to render properly. A tabs container needs each tab to provide a unique name for routing. An accordion needs each panel to have a title. Rather than relying on convention, `childArgs` makes these requirements explicit and validated.

**How it works:**

1. **Container declares requirements** via `childArgs` in the `@block()` decorator:
```javascript
@block("my-plugin:tabs-container", {
  container: true,
  childArgs: {
    name: { type: "string", required: true, unique: true },
    icon: { type: "string" },
  },
})
```

2. **Children provide metadata** via `containerArgs` in the `renderBlocks()` config:
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

3. **Container accesses metadata** via `this.children`:
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

> :exclamation: **Important:** Always use `key="key"` when iterating over `this.children`. Each child has a unique `key` property that ensures stable rendering during navigation and re-renders. Without it, Ember may reuse DOM elements incorrectly when children change.

**The `unique` property:** Enforces uniqueness across sibling children. If two children have the same value for a `unique` arg, you get an error:

```
Duplicate value "settings" for containerArgs.name in children of "tabs-container".
Found at children[0] and children[2].
```

> :exclamation: **Important:** `unique` is only valid for primitive types (`string`, `number`, `boolean`), not arrays.

**Validation:**
- If a container has `childArgs`, all children must provide `containerArgs` with the required fields
- If a child provides `containerArgs` but the parent has no `childArgs` schema, you get an error
- Schema validation (types, required fields, uniqueness) happens at boot time

### From Code to Screen

Understanding when things happen helps debug issues. The journey from code to screen happens in two distinct phases: boot time (when the app starts) and render time (when users navigate).

**Boot time** is all about registration and validation. First, your pre-initializers run—this is when `api.registerBlock()` calls validate the block name, namespace, and decoration, then add each block to the registry. If you have custom outlets, they're registered here too via `api.registerBlockOutlet()`. Core outlets are pre-registered.

Next, the `freeze-block-registry` initializer runs. This is a critical moment: it registers the built-in blocks (like `group`) and all the core condition types, then freezes all the registries. After this point, no more registrations are allowed—the set of available blocks, outlets, and condition types is fixed for the session.

Finally, your api-initializers run. When you call `api.renderBlocks()`, the system validates everything: does the outlet exist? Are all referenced blocks registered? Do the args match their schemas? Are the conditions syntactically valid? If validation passes, the layout configuration is stored for later use.

**Render time** happens when users actually see the page. When a `<BlockOutlet>` component renders, it retrieves the stored layout configuration and begins preprocessing. Conditions are evaluated bottom-up—children before parents—because a container's visibility depends on whether it has any visible children. Each block gets marked visible or hidden based on its conditions.

Finally, visible blocks render their components. Hidden blocks simply don't appear in the DOM—unless debug mode is enabled, in which case they show as ghost placeholders so you can see what's missing.

**The key insight:** most validation happens at boot time, not render time. Typos in condition types, invalid arg names, unregistered blocks—all of these surface as errors during boot. But when a condition fails at runtime? The block silently doesn't render (or shows as a ghost in debug mode). This design catches configuration mistakes early while allowing dynamic visibility at runtime.

> :bulb: When lazy-loaded blocks are involved (blocks registered with a factory function like `() => import("./my-block")` for code splitting), schema and constraint validations are deferred to when the layout is rendered for the first time.

Now that you've seen how blocks flow from registration to rendering, let's look at the building blocks in more detail.

---

## 2. The Moving Parts

Section 1 showed you *what* blocks are—the mental model, the anatomy, the lifecycle. Now let's look at *how* to work with them. We'll cover the `@block` decorator, the `<BlockOutlet>` component, and the `renderBlocks()` function, starting with a question you'll likely have: when should I use blocks versus plugin outlets?

### Blocks and Plugin Outlets

A question that often comes up: when should you use blocks versus plugin outlets? They serve different purposes, and understanding their strengths helps you choose the right tool:

| Aspect | Blocks | Plugin Outlets |
|--------|--------|----------------|
| **Best for** | Structured layout regions | Small additions or custom one-offs |
| **Reusability** | High—define once, use in many layouts | Lower—typically outlet-specific connectors |
| **Markup** | Standardized wrapper with consistent styling hooks | You control all markup |
| **Conditions** | Declarative, validated at boot | Custom logic in your component |
| **Composition** | Theme orchestrates layout from registered blocks | Connectors coexist independently |
| **Typical use** | Homepage sections, sidebars, dashboards | Badges, buttons, complex interactive features |

**They can coexist.** A category page might use:
- Blocks for its main content area (grid of panels, reusable across pages)
- Plugin outlets for small additions or highly custom interactive features

**Use blocks when:**
- You have a layout region that should display composed content (panels, cards, sections)
- You want reusable components that work across multiple outlets
- You want themes to control what appears and in what order
- You benefit from standardized wrapper markup and boot-time validation

**Use plugin outlets when:**
- You're making small additions to existing UI (badges, buttons)
- You need full control over markup and behavior
- You're building complex, highly customized features that don't fit the composed layout model

With that context in mind, let's dive into the mechanics of the Blocks API—how to register blocks, configure layouts, and place outlets in templates.

### Using the Blocks API

This subsection covers the practical APIs: registering blocks, composing layouts with `renderBlocks()`, and placing `<BlockOutlet>` components in templates. We'll start with who does what, then look at how the pieces connect.

#### Registering and Composing

By design, the Blocks API separates **registering blocks** from **composing layouts**. This separation of concerns makes it easier to reason about what belongs where—but real-world usage is flexible. Plugins sometimes need to compose layouts, and themes sometimes provide blocks. Here's the mental model:

**Core** provides built-in blocks—pre-registered and always available:
- `group`: A general-purpose container for organizing related blocks
- `first-match`: A conditional container for "if/else" logic

Both are documented in detail in the "Built-in Blocks" subsection below, with full schemas and usage examples.

**Plugins** register blocks:
```javascript
// plugins/discourse-analytics/pre-initializers/register-blocks.js
api.registerBlock(StatsPanel);  // Adds to registry
```

**Theme components** can also register blocks:
```javascript
// themes/my-theme/theme-component/pre-initializers/register-blocks.js
api.registerBlock(CustomPanel);  // Also adds to registry
```

**Themes** compose the layout:
```javascript
// themes/my-theme/api-initializers/configure-blocks.js
api.renderBlocks("homepage-blocks", [
  { block: "discourse-analytics:stats-panel?" },  // From plugin
  { block: "theme:my-theme:custom-panel" },       // From theme component
]);
```

This separation means:
- Plugins provide functionality without controlling layout
- Theme components extend the theme's own capabilities
- The theme decides what appears where

#### Built-in Blocks

Core provides container blocks that you can use without registration. Understanding these helps you structure layouts effectively.

**The `group` Block**

The `group` block is a general-purpose container for organizing related blocks together. It renders all its visible children in sequence, wrapped in a styled container element.

Schema:
```javascript
@block("group", {
  container: true,
  description: "Groups multiple children blocks together under a named wrapper",
  args: {
    name: { type: "string", pattern: VALID_BLOCK_NAME_PATTERN, required: true },
  },
  containerClassNames: (args) => `block__group-${args.name}`,
})
```

The `name` arg uses `VALID_BLOCK_NAME_PATTERN` (imported from `discourse/lib/blocks`) to ensure the name follows valid block naming conventions—lowercase letters, numbers, and hyphens.

The required `name` arg serves two purposes: it identifies the group for styling (via the generated `block__group-{name}` class) and for debugging (appearing in dev tools output).

Usage example:
```javascript
api.renderBlocks("homepage-blocks", [
  {
    block: "group",
    args: { name: "featured" },
    children: [
      { block: PromoBanner },
      { block: FeaturedTopics },
    ],
  },
  {
    block: "group",
    args: { name: "recent" },
    children: [
      { block: RecentActivity },
      { block: TrendingTags },
    ],
  },
]);
```

This creates two distinct visual sections you can style independently via CSS:
```css
.block__group-featured {
  background: var(--tertiary-low);
  padding: 2rem;
}

.block__group-recent {
  border-top: 1px solid var(--primary-low);
}
```

**The `first-match` Block**

The `first-match` block implements conditional branching—like a switch statement, it evaluates children in order and renders only the first one whose conditions pass.

Schema:
```javascript
@block("first-match", {
  container: true,
  // No args required - it's purely a conditional container
})
```

Usage example (showing different content based on user state):
```javascript
api.renderBlocks("welcome-area", [
  {
    block: "first-match",
    children: [
      {
        block: AdminDashboard,
        conditions: { type: "user", admin: true },
      },
      {
        block: ModeratorTools,
        conditions: { type: "user", moderator: true },
      },
      {
        block: MemberWelcome,
        conditions: { type: "user", loggedIn: true },
      },
      {
        block: GuestWelcome,
        // No conditions = fallback (always matches if reached)
      },
    ],
  },
]);
```

The order matters: the first matching child wins. In this example, admins see `AdminDashboard`, moderators (who aren't admins) see `ModeratorTools`, logged-in members see `MemberWelcome`, and anonymous visitors see `GuestWelcome`. The fallback child (no conditions) catches everyone else.

**Choosing Between `group`, `first-match`, and Direct Conditions**

With three ways to structure your blocks, here's a quick decision guide:

| Scenario | Use This | Why |
|----------|----------|-----|
| Multiple blocks that should all render together | `group` | Groups related content, provides a styled container |
| Mutually exclusive alternatives (only one should render) | `first-match` | Evaluates in order, renders only the first match |
| Independent blocks with unrelated conditions | Direct conditions | Each block stands alone, simpler to configure |
| A default fallback when nothing else matches | `first-match` | Last child without conditions catches everything |

**Common patterns:**

```javascript
// Pattern 1: Multiple independent blocks with conditions
[
  { block: WelcomeBanner, conditions: { type: "user", loggedIn: false } },
  { block: AdminPanel, conditions: { type: "user", admin: true } },
  { block: RecentTopics },  // Always shows
]
// All three evaluate independently. Anonymous users see WelcomeBanner + RecentTopics.
// Admins see AdminPanel + RecentTopics.

// Pattern 2: Mutually exclusive alternatives
[
  {
    block: "first-match",
    children: [
      { block: AdminView, conditions: { type: "user", admin: true } },
      { block: MemberView, conditions: { type: "user", loggedIn: true } },
      { block: GuestView },  // Fallback
    ],
  },
]
// Exactly one renders. Admin? AdminView. Non-admin member? MemberView. Anonymous? GuestView.

// Pattern 3: Organized sections with a container
[
  {
    block: "group",
    args: { name: "featured" },
    children: [
      { block: HeroBanner },
      { block: FeaturedTopics },
    ],
  },
]
// Both children render (if their conditions pass), wrapped in a styled container.
```

#### Composing Layouts

Now that you understand who should do what, let's look at how layouts are composed. The `renderBlocks()` function configures which blocks appear in an outlet:

```javascript
api.renderBlocks("homepage-blocks", [
  { block: Banner, args: { title: "Welcome" } },
  { block: "analytics:stats-panel?" },  // Optional block from plugin
  { block: Sidebar, conditions: { type: "user", loggedIn: true } },
]);
```

Each object in the array is a **block entry** specifying which block to render and how to configure it. Blocks can be referenced two ways:

- **By class** - Import and pass directly: `{ block: Banner }`
- **By name** - Use the registered string name: `{ block: "analytics:stats-panel" }`

String names enable cross-plugin references where you can't import the class directly. See the "Block entry properties" table in section 1 for all available options.

**Optional Blocks**

When using string names, you can append `?` to make the block **optional**:

```javascript
// Given a hypothetical "dashboard" outlet:
api.renderBlocks("dashboard", [
  { block: "analytics:stats-panel?" },  // Optional - won't error if missing
  { block: "chat:recent-messages?" },   // Optional
  { block: CoreBanner },                // Required - will error if not registered
]);
```

**Why optional blocks?**

Themes often want to compose blocks from multiple plugins, but those plugins may not be installed or could be disabled by the admin. Without optional blocks, the theme would crash if any referenced plugin is missing.

| Scenario | Required Block | Optional Block (`?`) |
|----------|----------------|----------------------|
| Block registered | ✓ Renders | ✓ Renders |
| Block not registered | ✗ Error thrown | ✓ Silently skipped |
| Plugin disabled | ✗ Error thrown | ✓ Silently skipped |

**When to use optional blocks:**

- **Theme referencing plugin blocks** - Plugins may not be installed
- **Cross-plugin integration** - Plugin A wants to use Plugin B's block if available
- **Graceful degradation** - Dashboard that works with any subset of plugins

**When NOT to use optional blocks:**

- **Block you own** - If you register and render the same block, it should always exist
- **Core blocks** - Core blocks are always available
- **Required dependencies** - If the block is essential, fail loudly

> :bulb: In debug mode, optional missing blocks appear as ghost placeholders with the message "This optional block is not rendered because it's not registered." This helps you see what *would* render if the plugin were active.

**Outlet Ownership**

Each outlet can only have one `renderBlocks()` configuration—the first caller owns it, and subsequent calls raise an error. While themes typically compose layouts, plugins and theme components *can* call `renderBlocks()` when they need full control of an outlet.

This works well for self-contained plugins that own specific UI areas, turnkey solutions providing a complete experience, or heavily customized instances where extensions are coordinated. Avoid this pattern when building reusable components meant for multiple themes, or when multiple extensions might reasonably customize the same outlet—in those cases, stick to registering blocks and let themes compose.

#### Architectural Patterns

These ownership rules lead to a few common patterns worth knowing upfront.

**Pattern A: Theme Composes Plugin Blocks (Recommended)**

Plugins register blocks, theme arranges them:

```
plugins/analytics/     → api.registerBlock(StatsPanel)
plugins/tasks/         → api.registerBlock(TaskList)
themes/my-theme/       → api.renderBlocks("homepage-blocks", [
                           { block: "analytics:stats-panel?" },
                           { block: "tasks:task-list?" },
                         ])
```

This is the recommended approach because it keeps plugins interoperable. Each plugin focuses on functionality; the theme decides presentation. Multiple plugins can coexist because none of them try to own the layout.

**Pattern B: Self-Contained Plugin**

Plugin owns a specific outlet no one else needs:

```
plugins/my-plugin/     → api.registerBlock(MyPanel)
                       → api.renderBlocks("my-plugin-outlet", [...])
```

Works when the outlet is truly plugin-specific—perhaps an outlet the plugin itself creates via `registerBlockOutlet()`. The plugin provides a turnkey experience without requiring theme configuration.

**Anti-Pattern: Competing for the Same Outlet**

```
plugins/plugin-a/      → api.renderBlocks("homepage-blocks", [...])  // Claims it
plugins/plugin-b/      → api.renderBlocks("homepage-blocks", [...])  // ERROR!
```

If two plugins call `renderBlocks()` on the same outlet, the second fails. This is why Pattern A is recommended—plugins register, themes compose.

#### Creating Blocks

Once you're composing layouts, you may want to create your own blocks. The `@block` decorator transforms a Glimmer component into a block. It adds:

- **Static properties** for introspection: `blockName`, `blockShortName`, `blockNamespace`, `blockType`, `blockMetadata`
- **Validation** at decoration time: name format, args schema, outlet patterns

```javascript
@block("theme:my-theme:banner", {
  description: "A promotional banner",
  args: { title: { type: "string", required: true } },
  allowedOutlets: ["homepage-*"],
})
class Banner extends Component { ... }
```

Most themes and plugins just use existing blocks. Create your own when you need custom rendering logic or want to encapsulate reusable UI patterns.

See section 1 "What's Inside a Block" for the complete decorator options including args schemas, constraints, and outlet restrictions.

#### Adding Block Outlets

The `<BlockOutlet>` component defines where blocks render in templates. Core and plugins use this to create outlet locations that themes can then populate. Remember from Section 1: outlets are the "rooms" where blocks live—you can't place a block without one.

```handlebars
<BlockOutlet @name="homepage-blocks" />
```

That's the simplest form—just a named location. The outlet waits for someone to call `renderBlocks()` with its name, then renders whatever blocks are configured.

**Outlet Args**

Some outlets need to pass contextual data to their blocks. A topic sidebar needs to tell blocks which topic is being viewed. A user profile outlet needs to share the user object. This is done via `@outletArgs`:

```handlebars
{{! Example: a hypothetical outlet in a topic header template }}
<BlockOutlet
  @name="topic-header-blocks"
  @outletArgs={{hash topic=this.model user=this.currentUser}}
/>
```

> :exclamation: **Key difference from plugin outlets:** In blocks, outlet args are accessed via `@outletArgs`, not `@args`. This is different from plugin outlet connectors where you'd use `@outletArgs.topic` or just `@topic`.
>
> The `@args` namespace in blocks is reserved for the block's layout entry args (from `renderBlocks()`). This separation is intentional—it clearly distinguishes "data from the template context" (`@outletArgs`) from "data from the layout configuration" (`@args`).

Here's how both look in practice:

```javascript
// In your block component:
<template>
  {{! Layout entry args - configured in renderBlocks() }}
  <h2>{{@title}}</h2>
  <p class={{@variant}}>...</p>

  {{! Outlet args - passed from the template via @outletArgs }}
  <p>Topic: {{@outletArgs.topic.title}}</p>
  <p>Author: {{@outletArgs.user.username}}</p>
</template>
```

In the layout configuration, you'd set the `@title` and `@variant` args:

```javascript
api.renderBlocks("topic-header-blocks", [
  {
    block: MyBlock,
    args: { title: "Related Content", variant: "highlighted" },  // becomes @title, @variant
  },
]);
```

The `@outletArgs.topic` and `@outletArgs.user` come from the BlockOutlet's `@outletArgs` prop in the template—the layout configuration doesn't control those.

Conditions can reference outlet args with the `outletArg` condition type or `source` parameters on other conditions (covered in detail in Section 3).

**System Args**

In addition to outlet args, the block system automatically provides a system arg to all blocks:

| Arg | Type | Description |
|-----|------|-------------|
| `@outletName` | `string` | The outlet identifier this block is rendered in (e.g., `"homepage-blocks"`) |

Access it in your block template just like any other arg:

```javascript
<template>
  {{! Access the outlet name for conditional styling or logic }}
  <div class="my-block my-block--in-{{@outletName}}">
    {{@title}}
  </div>
</template>
```

The system uses `@outletName` internally for:
- **CSS class generation:** Wrapper classes like `{outletName}__block` and `{outletName}__{name}` for BEM-style scoping
- **Debug context:** Identifying which outlet a block belongs to in error messages and dev tools

You typically don't need to access `@outletName` directly—the system handles CSS class generation automatically. However, it's available if your block needs outlet-specific behavior or styling.

**Named Blocks: `:before` and `:after`**

Sometimes you need to render content around your blocks—a header before them, an empty state after. BlockOutlet supports Ember's named blocks pattern for this:

```handlebars
<BlockOutlet @name="homepage-blocks">
  <:before as |isConfigured|>
    {{#if isConfigured}}
      <h2>Featured Content</h2>
    {{/if}}
  </:before>

  <:after as |isConfigured|>
    {{#unless isConfigured}}
      <p class="empty-state">No content has been configured for this area.</p>
    {{/unless}}
  </:after>
</BlockOutlet>
```

Both named blocks receive a boolean parameter indicating whether **any blocks are configured** for this outlet (i.e., whether `renderBlocks()` was called for it).

**When to use each:**

| Named Block | Renders | Common Uses |
|-------------|---------|-------------|
| `:before` | Before all blocks | Section headers, introductory text, "featured" labels |
| `:after` | After all blocks | Empty states, fallback content, "see more" links |

**`:before` examples:**

```handlebars
{{! Add a header only when blocks exist }}
<BlockOutlet @name="sidebar-panels">
  <:before as |isConfigured|>
    {{#if isConfigured}}
      <h3 class="sidebar-panels__header">Panels</h3>
    {{/if}}
  </:before>
</BlockOutlet>

{{! Always show a header, but style differently }}
<BlockOutlet @name="announcements">
  <:before as |isConfigured|>
    <h2 class={{if isConfigured "has-content"}}>Announcements</h2>
  </:before>
</BlockOutlet>
```

**`:after` examples:**

```handlebars
{{! Show empty state when no blocks configured }}
<BlockOutlet @name="user-dashboard">
  <:after as |isConfigured|>
    {{#unless isConfigured}}
      <div class="empty-dashboard">
        <p>Your dashboard is empty. Install plugins to add panels.</p>
      </div>
    {{/unless}}
  </:after>
</BlockOutlet>

{{! Show "view all" link when blocks exist }}
<BlockOutlet @name="recent-activity">
  <:after as |isConfigured|>
    {{#if isConfigured}}
      <a href="/activity" class="view-all">View all activity →</a>
    {{/if}}
  </:after>
</BlockOutlet>
```

**Combining both:**

```handlebars
<BlockOutlet @name="topic-sidebar">
  <:before as |isConfigured|>
    {{#if isConfigured}}
      <div class="sidebar-header">
        <h3>Related</h3>
      </div>
    {{/if}}
  </:before>

  <:after as |isConfigured|>
    {{#if isConfigured}}
      <div class="sidebar-footer">
        <button class="collapse-sidebar">Collapse</button>
      </div>
    {{else}}
      <p class="no-sidebar">No sidebar content for this topic.</p>
    {{/if}}
  </:after>
</BlockOutlet>
```

**Important distinction:** The boolean tells you if blocks are *configured*, not if they're *visible*. If you configure three blocks but all their conditions fail, `isConfigured` is still `true`—the outlet has configuration, it just has no visible output. This is intentional: it distinguishes "no one set this up" from "it's set up but nothing applies right now."

Now that you know how to register, compose, and create blocks, the next question is: how do you express "show this to admins" or "only on the homepage"?

---

## 3. Show This, Hide That

Every visibility rule is a **condition**—a declarative object that the system evaluates at render time. No imperative code, just data describing what should be true for a block to show.

Conditions have a `type` and options specific to that type:

```javascript
{ type: "user", loggedIn: true }           // Check user state
{ type: "route", pages: ["TOPIC_PAGES"] }  // Check current page
{ type: "setting", name: "dark_mode" }     // Check a setting
```

Conditions can see several things:
- **Outlet args** passed from the template via `@outletArgs`
- **Services** like `currentUser`, `siteSettings`, `router` (in custom conditions)
- **Debug context** when logging is enabled

**The `source` parameter:** Some conditions support a `source` parameter that changes *what* they check. By default, the `user` condition checks the person viewing the page, and the `setting` condition checks site settings. But what if you're on a user profile page and want to show a badge based on the *profile owner's* trust level, not the viewer's? Or you want to check theme settings instead of site settings? The `source` parameter lets you redirect the condition to check a different data source. You'll see examples of this in the specific condition types below.

The system provides five built-in condition types: `user`, `route`, `setting`, `viewport`, and `outletArg`. Let's start by exploring what each one does, then look at how to combine them for more complex requirements.

### Built-in Conditions

Five condition types ship with Discourse, each designed for a specific category of visibility logic:

| When you want to... | Use this condition |
|---------------------|-------------------|
| Show content based on who's viewing (logged in, admin, trust level) | `user` |
| Check a site or theme setting | `setting` |
| Respond to screen size or device type | `viewport` |
| Check data passed from the template (topic properties, user objects) | `outletArg` |
| Match specific pages, URLs, or navigation contexts | `route` |

Most blocks need only one or two condition types. A welcome banner might just check `user.loggedIn`. A category sidebar might combine `route` (to target category pages) with `outletArg` (to check category properties). Start with the simplest condition that achieves your goal—you can always add more later.

#### User Condition

The user condition is probably the one you'll reach for most often. It lets you control visibility based on who's viewing the page—whether they're logged in, their role (admin, moderator, staff), their trust level, or their group membership.

By default, the condition checks the **current user**—the person viewing the page. This handles the common case where you want to show something to admins or hide something from anonymous visitors. But you can also check a *different* user via the `source` option, which is useful when you're rendering content about a topic author or profile owner and want to show extra details based on *their* properties, not the viewer's.

Here's an example showing all available options (you'd never use all of these together—just pick what you need):

```javascript
{ type: "user", loggedIn: true, admin: true, moderator: true, staff: true,
  minTrustLevel: 0, maxTrustLevel: 4, groups: ["beta-testers"] }
```

All properties are optional—include only what you need to check. When you specify multiple properties, they all must be true (AND logic). The following table provides a quick reference:

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

**Multiple properties use AND logic:**
```javascript
// User must be logged in AND trust level 2+ AND in beta-testers group
{ type: "user", loggedIn: true, minTrustLevel: 2, groups: ["beta-testers"] }
```

**Check outlet arg user:**
```javascript
// Check the topic author instead of current user
{ type: "user", source: "@outletArgs.topicAuthor", admin: true }
```

**Choosing the right check:** Use `staff` when moderators and admins should see the same thing. Use `admin` or `moderator` separately when their experiences should differ. Use `groups` for feature rollouts to specific user segments.

In practice, most user conditions are simple: `{ type: "user", loggedIn: true }` for member-only content, `{ type: "user", admin: true }` for admin tools, or `{ type: "user", minTrustLevel: 2 }` for experienced members. The more complex combinations—trust level ranges, multiple group requirements—tend to appear in specialized plugins rather than typical theme layouts.

#### Setting Condition

The setting condition lets you tie block visibility to site configuration. Want a promo banner that only shows when a "show_promotions" setting is enabled? Or a panel that changes based on a dropdown setting's value? This is your tool.

Discourse has different types of settings—boolean toggles, string values, enum dropdowns, and list settings (comma-separated values). The setting condition handles all of these with different comparison modes. You specify `name` to identify the setting, then pick *one* comparison mode to check its value.

Here's the full syntax (but remember, you'd only use one comparison mode at a time):

```javascript
{ type: "setting", name: "setting_name", enabled: true, equals: "value",
  includes: [...], contains: "value", containsAny: [...], source: {...} }
```

The `name` property is always required—it identifies which setting to check. The comparison modes give you different ways to check the setting's value:

| Property | Type | Description |
|----------|------|-------------|
| `name` | `string` | Setting key (required) |
| `enabled` | `boolean` | true = setting truthy, false = setting falsy |
| `equals` | `any` | Exact value match |
| `includes` | `array` | Setting value is in this array (for enum settings) |
| `contains` | `string` | List setting contains this value |
| `containsAny` | `array` | List setting contains any of these values |
| `source` | `object` | Custom settings object (e.g., theme settings) |

**Only one comparison mode per setting:**
```javascript
// WRONG - multiple condition types
{ type: "setting", name: "foo", enabled: true, equals: "bar" }

// RIGHT - one condition type
{ type: "setting", name: "foo", enabled: true }
// OR
{ type: "setting", name: "foo", equals: "bar" }
```

**Theme settings:**
```javascript
import { settings } from "virtual:theme";

// Check theme setting instead of site setting
{ type: "setting", source: settings, name: "show_sidebar", enabled: true }
```

**Site settings vs theme settings:** Use site settings for admin-controlled features. Use theme settings when the theme itself controls the behavior, allowing different themes to have different defaults.

The most common pattern is a simple boolean toggle: `{ type: "setting", name: "show_announcements", enabled: true }`. This lets admins control block visibility from the site settings page without touching code. For more sophisticated control—like showing different blocks based on a dropdown setting—use `equals` or `includes`.

So far we've checked *who* is viewing and *what the configuration says*. But what about *where* they're viewing from? The next condition handles device and screen size.

#### Viewport Condition

The viewport condition responds to screen size and device type. Use it when you want to show completely different blocks on mobile versus desktop, or when you need to prevent a component from rendering at all below a certain size (perhaps because it fetches data that's irrelevant on small screens).

A word of caution: for simple show/hide scenarios, CSS media queries are usually more performant. The viewport condition's strength is when you need to *prevent rendering entirely* or combine viewport checks with other conditions. If you just want to hide something visually, CSS is the better choice.

```javascript
{ type: "viewport", min: "lg", max: "xl", mobile: true, touch: true }
```

The breakpoints follow a simple pattern: each name represents a minimum screen width, from small (`sm`) to extra-large (`2xl`):

- `sm` - ≥640px (larger phones, small tablets)
- `md` - ≥768px (tablets)
- `lg` - ≥1024px (laptops, small desktops)
- `xl` - ≥1280px (desktops)
- `2xl` - ≥1536px (large desktops)

You can check specific breakpoint ranges, or use device-type checks for a broader approach:

| Property | Type | Description |
|----------|------|-------------|
| `min` | `string` | Viewport must be at least this size |
| `max` | `string` | Viewport must be at most this size |
| `mobile` | `boolean` | true = mobile device only, false = non-mobile only |
| `touch` | `boolean` | true = touch device only, false = non-touch only |

```javascript
// Large screens only
{ type: "viewport", min: "lg" }

// Small screens only (mobile)
{ type: "viewport", max: "sm" }

// Medium to large screens
{ type: "viewport", min: "md", max: "xl" }

// Touch devices only
{ type: "viewport", touch: true }
```

> :bulb: For simple show/hide based on viewport, CSS media queries are often more performant. Use this condition when you need to prevent a component from rendering entirely—for example, to avoid unnecessary data fetching on mobile, or to show completely different blocks based on screen size.

We've covered who's viewing (`user`), what settings say (`setting`), and what device they're using (`viewport`). The next two conditions look at the page itself: what data is available in the current context, and what URL or page type we're on.

#### OutletArg Condition

When outlets pass contextual data via `@outletArgs`, you can make visibility decisions based on that data. This is how you build truly context-aware blocks—showing a "mark as solved" button only on unsolved topics, or displaying author badges only when viewing a staff member's profile.

The condition works by navigating to a property in the outlet args and checking its value. You specify a `path` using dot notation (like `topic.closed` or `user.trust_level`), then either check what that value equals (`value`) or whether it exists at all (`exists`).

```javascript
{ type: "outletArg", path: "topic.closed", value: true }
```

The `path` property uses dot notation to navigate nested objects. You then specify either a value match or an existence check:

| Property | Type | Description |
|----------|------|-------------|
| `path` | `string` | Dot-notation path to property (required) |
| `value` | `any` | Value to match (see matching rules) |
| `exists` | `boolean` | true = property exists, false = property undefined |

> :warning: You cannot use both `value` and `exists` together—they are mutually exclusive. Use `value` to check what something equals, use `exists` to check whether it's defined at all.

In practice, you'll use `value` most often—checking if a topic is closed, or if a category has a specific slug. The `exists` check is useful when the presence of a property matters regardless of its value, like checking whether a topic has any tags at all rather than checking for specific tags.

**Value matching rules:**
- Primitive value → passes if target === value (strict equality)
- `[a, b, c]` → passes if target matches ANY element (OR logic)
- `{ not: x }` → passes if target does NOT match x
- `{ any: [...] }` → passes if target matches ANY spec in array (OR logic)
- RegExp → passes if target (coerced to string) matches the pattern

```javascript
// Check if topic is closed
{ type: "outletArg", path: "topic.closed", value: true }

// Check trust level is 2, 3, or 4
{ type: "outletArg", path: "user.trust_level", value: [2, 3, 4] }

// Check topic is NOT closed
{ type: "outletArg", path: "topic.closed", value: { not: true } }

// Check if topic property exists
{ type: "outletArg", path: "topic", exists: true }
```

OutletArg conditions are your tool for context-aware blocks—showing different content based on the specific topic, user, or category being viewed. The route condition, up next, handles broader navigation contexts.

#### Route Condition

The route condition is the most powerful—and the most complex—of the built-in conditions. It lets you target specific pages, entire sections of the site, or precisely filtered views. Want a promo to show only on the homepage? A sidebar widget only on category pages? A feature announcement only on the latest topics list with a specific query parameter? Route conditions handle all of these.

The condition offers two complementary approaches: URL pattern matching (for precise path control) and semantic page types (for logical section targeting). You can use either or both, depending on your needs.

```javascript
{ type: "route", urls: [...], pages: [...], params: {...}, queryParams: {...} }
```

> **Why URLs instead of Ember route names?** Using internal route names like `discovery.latest` would make them part of the public API—any rename would break plugins and themes. URLs are already effectively public: changing them breaks bookmarks, external links, and SEO. By matching URLs, we avoid coupling blocks to Discourse's internal routing structure.

The two approaches complement each other:
- **`urls`**: Match URL patterns using glob syntax—precise path control
- **`pages`**: Match semantic page types—logical section targeting that survives URL changes

**URL Patterns (`urls` option):**

When you need exact path matching or complex wildcard patterns, use URLs. The system uses [picomatch](https://github.com/micromatch/picomatch) glob syntax:
- `"/latest"` - Exact path match
- `"/c/*"` - Single segment wildcard (`/c/foo` but not `/c/foo/bar`)
- `"/c/**"` - Multi-segment wildcard (`/c/foo`, `/c/foo/bar`, `/c/foo/bar/baz`)
- `"/t/*/**"` - Combined (`/t/123/slug`, `/t/123/slug/4`)
- `"/{latest,top}"` - Brace expansion (matches either)

**Semantic Page Types (`pages` option):**

Page types represent Discourse's main navigation contexts. Think of them as logical groupings that abstract away the specific URL structure. When you target `TAG_PAGES`, you're saying "anywhere a tag listing is shown"—whether that's `/tag/featured`, `/tags/c/general/13`. This abstraction means your conditions keep working even if the site's URL structure changes.

Each page type can optionally be refined with parameters. For example, `TAG_PAGES` by itself matches all category pages, but `{ pages: ["TAG_PAGES"], params: { categoryId: 5 } }` matches only a specific category.

| Page Type | Description | Parameters |
|-----------|-------------|------------|
| `CATEGORY_PAGES` | Category listing pages | `categoryId` (number), `categorySlug` (string), `parentCategoryId` (number) |
| `TAG_PAGES` | Tag listing pages | `tagId` (string), `categoryId` (number), `categorySlug` (string), `parentCategoryId` (number) |
| `DISCOVERY_PAGES` | Discovery routes (latest, top, etc.) | `filter` (string) |
| `HOMEPAGE` | Custom homepage only | (none) |
| `TOP_MENU` | Top nav discovery routes | `filter` (string) |
| `TOPIC_PAGES` | Individual topic pages | `id` (number), `slug` (string) |
| `USER_PAGES` | User profile pages | `username` (string) |
| `ADMIN_PAGES` | Admin section pages | (none) |
| `GROUP_PAGES` | Group pages | `name` (string) |

**Choosing between URLs and Pages:**

Choose `pages` when:
- You want to match a logical section (all category pages, all topic pages)
- You need typed parameters like `categoryId` or `username`

Choose `urls` when:
- You need exact path matching
- You're targeting custom routes not covered by page types
- You need glob patterns for a specific URL structure

```javascript
// Page type: matches category pages regardless of URL structure
{ type: "route", pages: ["CATEGORY_PAGES"] }

// URL pattern: matches specific path structure
{ type: "route", urls: ["/c/**"] }

// The URL pattern might miss category pages with custom routes
// The page type checks the actual page context
```

**Page Parameters (`params` option):**

The `params` option works only with `pages` (not `urls`) and validates parameters against the page type definitions:

```javascript
// Match specific category by ID
{ type: "route", pages: ["CATEGORY_PAGES"], params: { categoryId: 5 } }

// Match category by slug
{ type: "route", pages: ["CATEGORY_PAGES"], params: { categorySlug: "general" } }

// Match subcategory by parent category ID
{ type: "route", pages: ["CATEGORY_PAGES"], params: { parentCategoryId: 5 } }

// Match discovery pages with specific filter
{ type: "route", pages: ["DISCOVERY_PAGES"], params: { filter: "latest" } }

// Match specific tag
{ type: "route", pages: ["TAG_PAGES"], params: { tagId: "javascript" } }

// Match tag filtered by category
{ type: "route", pages: ["TAG_PAGES"], params: { tagId: "javascript", categoryId: 5 } }

// Match specific topic
{ type: "route", pages: ["TOPIC_PAGES"], params: { id: 123 } }

// Match specific user profile
{ type: "route", pages: ["USER_PAGES"], params: { username: "admin" } }
```

**Multiple Page Types (OR logic):**

```javascript
// Match category OR tag pages
{ type: "route", pages: ["CATEGORY_PAGES", "TAG_PAGES"] }

// With params: params must be valid for ALL listed page types
// This works because both CATEGORY_PAGES and TAG_PAGES support 'categoryId'
{ type: "route", pages: ["CATEGORY_PAGES", "TAG_PAGES"], params: { categoryId: 5 } }

// This works because both DISCOVERY_PAGES and TOP_MENU support 'filter'
{ type: "route", pages: ["DISCOVERY_PAGES", "TOP_MENU"], params: { filter: "latest" } }
```

**Params with `any` and `not` Operators:**

The `params` object supports `any` (OR) and `not` (NOT) operators for complex matching. These are the same operators used for combining conditions (covered in detail in the next subsection "Combining Conditions"), but here they work within a single route condition's parameters:

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

// Combined: Match if NOT in categories 1, 2, or 3
{
  type: "route",
  pages: ["CATEGORY_PAGES"],
  params: { not: { any: [{ categoryId: 1 }, { categoryId: 2 }, { categoryId: 3 }] } }
}

// Nested: Match if category 1 OR NOT category 2
{
  type: "route",
  pages: ["CATEGORY_PAGES"],
  params: { any: [{ categoryId: 1 }, { not: { categoryId: 2 } }] }
}
```

> :bulb: **Tip:** Use `any` in params when you want to match one of several specific values. Use `not` to exclude specific values while matching others.

**Query Parameters (`queryParams` option):**

Query params are useful for targeting filtered views—like showing a "Mark all solved" button only when users are viewing the solved filter, or hiding certain elements on specific sort orders.

Works with both `urls` and `pages`. Query params support the same `any` (OR) and `not` (NOT) operators as `params`:

```javascript
// Simple query param match
{
  type: "route",
  urls: ["/latest"],
  queryParams: { filter: "solved" }
}

// Multiple query params (AND - all must match)
{
  type: "route",
  pages: ["DISCOVERY_PAGES"],
  queryParams: { filter: "solved", order: "activity" }
}

// OR logic: match if filter is "solved" OR "open"
{
  type: "route",
  pages: ["DISCOVERY_PAGES"],
  queryParams: {
    any: [{ filter: "solved" }, { filter: "open" }]
  }
}

// NOT logic: match if filter is NOT "closed"
{
  type: "route",
  pages: ["DISCOVERY_PAGES"],
  queryParams: { not: { filter: "closed" } }
}

// Combined: match if NOT (filter is "solved" OR "open")
{
  type: "route",
  pages: ["DISCOVERY_PAGES"],
  queryParams: { not: { any: [{ filter: "solved" }, { filter: "open" }] } }
}
```

**Excluding Pages:**

Use the NOT combinator to exclude pages instead of a dedicated exclude option:

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

Now that you know what each condition type can check, what happens when you need more than one check? A block that should show for "logged-in admins on category pages" needs to combine three conditions. That's where combination syntax comes in.

### Combining Conditions

When blocks need more than one check, the Blocks API uses familiar boolean logic. You can combine conditions using AND, OR, and NOT operators—and nest them for complex requirements.

**Single condition (no array needed):**

When you only need one check, pass the condition object directly:

```javascript
conditions: { type: "user", loggedIn: true }
```

**AND logic (array):**

When multiple conditions must ALL be true, use an array. Every condition in the array must pass for the block to show:

```javascript
conditions: [
  { type: "user", loggedIn: true },
  { type: "route", pages: ["DISCOVERY_PAGES"] }
]
```

**OR logic (any wrapper):**

When you want a block to show if ANY condition passes, wrap your conditions in an `any` object. The block renders if at least one condition is true:

```javascript
conditions: {
  any: [
    { type: "user", admin: true },
    { type: "user", moderator: true }
  ]
}
```

**NOT logic (not wrapper):**

To invert a condition—show the block when the condition is false—use a `not` wrapper:

```javascript
conditions: { not: { type: "route", pages: ["ADMIN_PAGES"] } }
```

**Nesting for complex requirements:**

These patterns can be nested. Arrays inside `any` create AND groups within OR logic:

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

Think of it like boolean algebra: arrays are AND, `any` is OR, `not` inverts. The nesting depth is limited to 20 levels (matching the overall block nesting limit), though if you're approaching that, consider simplifying your logic or using a custom condition.

The built-in conditions combined with these operators cover most visibility scenarios. But sometimes you need something domain-specific—a feature flag system, subscription tiers, or custom business logic. That's when you create your own condition type.

### Rolling Your Own

Need something the built-ins don't cover? Maybe you have a feature flag service, a custom subscription system, or domain-specific logic that doesn't fit the standard conditions. You can create your own.

Custom conditions have two parts: the `@blockCondition` decorator and a class that extends `BlockCondition`. The decorator defines metadata—the type name (what you'll use in `{ type: "..." }`), the args schema, and optional validation. The class implements the actual logic in an `evaluate()` method that returns true or false.

Here's a feature flag condition:

```javascript
import { BlockCondition, blockCondition } from "discourse/blocks/conditions";
import { service } from "@ember/service";

@blockCondition({
  type: "feature-flag",
  args: {
    flag: { type: "string", required: true },
    enabled: { type: "boolean" },
  },
  // Custom validation runs after schema validation (types, required).
  // Use this for logic that can't be expressed declaratively.
  // Returns error string or null if valid.
  validate(args) {
    if (args.flag && !args.flag.match(/^[a-z][a-z0-9_]*$/)) {
      return "FeatureFlagCondition: `flag` must be lowercase with underscores.";
    }
    return null;
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

Custom conditions must be registered before the registry freezes. Use `api.registerBlockConditionType()` in a pre-initializer:

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

> :exclamation: **Important:** Registration must happen in a pre-initializer that runs before `"freeze-block-registry"`. If you register too late, you'll get an error: `api.registerBlockConditionType() was called after the condition type registry was frozen.`

**Using the custom condition:**

```javascript
{
  block: MyBlock,
  conditions: [{ type: "feature-flag", flag: "new_feature", enabled: true }]
}
```

With conditions defined, the next question is: what happens when the page actually renders? How does the system decide, in real-time, which blocks make the cut?

---

## 4. When Blocks Appear

When a `<BlockOutlet>` renders, it kicks off a decision process. The system doesn't just check conditions top-to-bottom—it uses **bottom-up evaluation** to handle containers correctly. This is the heart of the rendering pipeline.

### How Decisions Are Made

The key insight is **bottom-up evaluation**—children are processed before parents.

**Why bottom-up?** Container blocks have an implicit condition: they only render if they have at least one visible child. We need to know child visibility before we can determine parent visibility. Think of it like our furniture analogy: you can't decide if a shelving unit fits in the room until you know which drawer inserts and compartments will actually be used.

```
Block Tree:                    Evaluation Order:

  group                        4. group: visible if any child visible
   ├── banner-a                1. banner-a: evaluate conditions
   ├── banner-b                2. banner-b: evaluate conditions
   └── nested-group            3. nested-group: visible if any child visible
        ├── card-1                 a. card-1: evaluate conditions
        └── card-2                 b. card-2: evaluate conditions
```

The algorithm:

```javascript
for each entry in layout:
  1. Resolve block reference (string name → class)
  2. Evaluate entry's own conditions
  3. If container with children:
     a. Recursively preprocess children (this computes their visibility)
     b. Check if any child is visible
  4. Mark visible if conditions passed AND (not container OR has visible children)
  5. If not visible, record the reason for debug tools
```

### Figuring Out What to Show

Before conditions can be evaluated, block references must be resolved. The resolution phase handles three types of references:

**String Name Resolution:**
```javascript
// String reference → registry lookup
{ block: "discourse-analytics:stats-panel" }
// System looks up the name in the block registry and returns the component class
```

**Factory Function Resolution:**

Factory functions enable lazy loading for code splitting. They're declared during registration, then referenced by string name in layouts:

```javascript
// pre-initializers/register-blocks.js
api.registerBlock("my-plugin:heavy-block", () => import("./blocks/heavy-block"));

// api-initializers/configure-blocks.js
api.renderBlocks("dashboard", [
  { block: "my-plugin:heavy-block" },  // String reference, not the factory
]);
```

When the block is needed, the system calls the factory, resolves the Promise, extracts the default export, and caches the result.

> :warning: **Factory functions are evaluated only once.** The result is cached permanently for the session. Factories are for lazy loading, not conditional logic.

**Incorrect usage** (dynamic result):
```javascript
// ✗ Bad: Tries to return different blocks based on condition
// This will NOT work—the first result is cached forever
api.registerBlock("my-plugin:dynamic", () => {
  if (someCondition) {
    return import("./block-a");
  }
  return import("./block-b");
});
```

If you need conditional block selection, register both blocks and use conditions in the layout:
```javascript
// ✓ Good: Register both, use conditions to select
api.registerBlock(BlockA);
api.registerBlock(BlockB);

api.renderBlocks("outlet", [
  { block: BlockA, conditions: { type: "setting", name: "feature_a", enabled: true } },
  { block: BlockB, conditions: { type: "setting", name: "feature_a", enabled: false } },
]);
```

**Optional Block Handling:**
```javascript
// Optional marker (?) affects resolution behavior
{ block: "some-plugin:optional-block?" }
// If not found in registry:
//   - Without ?: throw BlockError
//   - With ?: return null, mark entry as __optional
```

Resolved classes are cached to avoid repeated async loads. Once resolved, a factory never executes again—the cached class is returned directly.

### How Conditions Work

After resolution, conditions are evaluated. The evaluation process has several important characteristics:

**Short-Circuit Evaluation:**

In production mode, AND conditions short-circuit—if any condition fails, remaining conditions aren't evaluated:

```javascript
conditions: [
  { type: "user", admin: true },      // If false → skip rest
  { type: "route", pages: ["ADMIN"] }, // Never evaluated if admin check failed
  { type: "setting", name: "x" }       // Never evaluated
]
```

In debug mode (when console logging is enabled), short-circuiting is disabled. All conditions are evaluated so the debug output shows the complete picture—you can see which conditions *would* have passed if earlier ones hadn't failed.

**Visibility Flags:**

After evaluation, each entry is marked with:

- **Visibility** - Whether the block should render
- **Failure reason** - Why it's hidden (shown in debug tools)

Failure reasons include:
- Condition failed - Block's own conditions returned false
- No visible children - Container has no visible children

> :bulb: Optional blocks that are not registered are handled separately via a marker object, not a failure reason. They simply don't appear in the rendered output.

**Container Visibility Logic:**

Container blocks have an implicit condition: they only render if at least one child is visible. This prevents empty container wrappers from appearing in the DOM.

In pseudocode:
```
visible = ownConditionsPassed AND (notContainer OR hasVisibleChildren)
```

### Caching Behavior

The Blocks API caches leaf blocks to optimize navigation performance.

**What Gets Cached:**

Leaf blocks (blocks without children) are cached based on:
- Component class reference
- Args object (compared using shallow equality)

When a user navigates between pages, if a leaf block's class and args match a cached entry (same class, shallow-equal args), the cached component is reused instead of creating a new one.

**What Doesn't Get Cached:**

Container blocks are never cached because:
- Their children may have different visibility on different pages
- The children array is route-dependent
- Re-evaluating children is necessary for correctness

**Cache Invalidation:**

The cache invalidates when:
- Args change (even if component class is the same)
- Component class changes
- App is refreshed

This caching is transparent—your block code doesn't need to account for it.

### What Makes Blocks Update

Conditions can depend on reactive state. When that state changes, the block tree re-evaluates.

**What Triggers Re-evaluation:**

- **Route transitions** - Navigating to a new page triggers re-evaluation of route conditions
- **User state changes** - Logging in/out, trust level changes, group membership changes
- **Site settings changes** - If a setting used in a condition is modified (rare at runtime)
- **Outlet args changes** - When parent component updates outlet args
- **Viewport changes** - Resizing browser window (for viewport conditions)

**How Re-evaluation Works:**

1. Tracked property changes notify Ember's reactivity system
2. BlockOutlets re-evaluates the block tree
3. All conditions re-evaluate with current state
4. Components update based on new visibility state

**Minimizing Re-renders:**

To keep re-evaluation efficient:
- Avoid complex conditions when simple ones suffice
- Use route conditions instead of outlet arg conditions when possible (routes change less frequently)
- Keep container hierarchies shallow

### Step-by-Step Evaluation Example

Let's trace through a complex condition tree to understand the evaluation order:

```javascript
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

**Evaluation (user is logged in, trust level 3, not admin, on /latest):**

```
Step 1: Evaluate top-level AND (array)
  ├─ Step 1a: { type: "user", loggedIn: true }
  │  └─ currentUser exists? YES → ✓ PASS
  │
  └─ Step 1b: { any: [...] }
     ├─ Step 1b-i: { type: "user", admin: true }
     │  └─ currentUser.admin? NO → ✗ FAIL
     │
     └─ Step 1b-ii: [ (nested AND) ]
        ├─ { type: "user", minTrustLevel: 2 }
        │  └─ currentUser.trust_level >= 2? (3 >= 2) YES → ✓ PASS
        │
        └─ { not: { type: "route", pages: ["ADMIN_PAGES"] } }
           └─ Is current page ADMIN_PAGES? /latest = NO
              └─ NOT(false) = true → ✓ PASS
        │
        └─ Nested AND: PASS && PASS = ✓ PASS
     │
     └─ any: FAIL || PASS = ✓ PASS
  │
  └─ Top-level AND: PASS && PASS = ✓ PASS

Result: Block renders
```

**Same evaluation, but user is admin on /admin page:**

```
Step 1: Evaluate top-level AND (array)
  ├─ Step 1a: { type: "user", loggedIn: true } → ✓ PASS
  │
  └─ Step 1b: { any: [...] }
     ├─ Step 1b-i: { type: "user", admin: true }
     │  └─ currentUser.admin? YES → ✓ PASS
     │
     └─ (short-circuit: any already passed, skip remaining)

Result: Block renders (admin bypass)
```

In debug mode, you'd see the full evaluation logged even though the `any` short-circuited in production.

> :bulb: This example uses condition combinators (`any`, `not`, nested arrays) to build complex logic. See **Section 3: Show This, Hide That** for the complete syntax reference on combining conditions.

### Performance Considerations

The Blocks API is designed to be fast by default, but understanding how it works helps you make good choices for your specific use case.

**Condition Evaluation Cost**

Conditions are evaluated at render time, which means they run on every page navigation and whenever reactive state changes. Built-in conditions are highly optimized—they access cached services and use simple property lookups. However, these costs can add up:

- **Deeply nested conditions** (many `any`/`not` wrappers) create more function calls
- **Large outlets** (many blocks with complex conditions) take proportionally longer to evaluate
- **Reactive triggers** (tracked properties that change frequently) cause re-evaluation

In practice, you're unlikely to hit performance problems with typical layouts. But if you notice sluggishness, enable debug mode to see which conditions are being evaluated and whether any complex condition trees might be causing overhead.

**Container Depth Limits**

Layouts cannot nest deeper than 20 levels. This limit exists primarily to prevent stack overflow from recursive configurations, but hitting it usually indicates a design issue rather than a technical constraint. Most layouts work well with 2-3 levels of nesting.

**Caching Behavior**

Several aspects of the block system are cached for performance:

- **Block classes** from factory functions (lazy loading) are cached permanently after first resolution
- **Condition type classes** are looked up once and cached
- **Outlet layouts** are preprocessed once per navigation, not per render cycle

This means the first render of a page with lazy-loaded blocks may be slightly slower as factories resolve, but subsequent renders are fast.

**CSS Media Queries vs Viewport Conditions**

For simple show/hide based on screen size, CSS media queries are usually more performant than the `viewport` condition:

```css
/* CSS approach - browser handles this natively */
.mobile-banner { display: none; }
@media (max-width: 768px) {
  .mobile-banner { display: block; }
}
```

Use the `viewport` condition when you need to:
- **Prevent rendering entirely** (avoid fetching data that won't be shown)
- **Swap completely different blocks** based on screen size
- **Combine viewport checks with other conditions** (e.g., "mobile AND logged in")

For purely visual show/hide without data implications, CSS is the better choice.

**Practical Guidance**

Based on typical usage patterns, here are some rough guidelines:

| Scenario | Typical Performance | Notes |
|----------|---------------------|-------|
| 1-10 blocks with simple conditions | Excellent | Most plugins/themes fall here |
| 10-30 blocks with moderate conditions | Good | Typical for busy homepages |
| 30-50 blocks or deeply nested conditions | Acceptable | Consider splitting into multiple outlets |
| 50+ blocks or 5+ nesting levels | May need optimization | Profile with debug mode |

These aren't hard limits—they're starting points for investigation. A simple outlet with 100 blocks might perform fine, while a complex outlet with 20 blocks and deeply nested `any`/`not` conditions might need attention.

**When to Optimize**

Don't optimize prematurely. The Blocks API is designed for typical UI extension use cases, and most plugins/themes won't need to think about performance. If you do notice issues:

1. **Enable debug mode** to see condition evaluation details—the console shows which conditions passed or failed and why
2. **Simplify conditions** by flattening deeply nested `any`/`not` structures
3. **Use CSS** for viewport-only visibility (no JavaScript evaluation overhead)
4. **Split large outlets** into smaller, more focused outlets (e.g., `homepage-hero` + `homepage-featured` instead of one giant `homepage-blocks`)
5. **Consider custom conditions** if you're repeating the same complex condition logic—a single condition class is often faster than deeply nested built-in conditions

That covers how the evaluation engine works. But what happens when you make a mistake configuring blocks?

---

## 5. When Things Go Wrong

You've seen how blocks flow through registration, configuration, and evaluation. But what if you typo a condition type? Pass the wrong arg type? Reference a block that doesn't exist? The Blocks API catches these mistakes early and explains them clearly—like furniture assembly instructions that stop you before you've bolted the wrong pieces together. Most validation happens at boot time, surfacing problems before users ever see a broken page.

### Helpful Error Messages

The Blocks API is designed to guide you toward the fix, not just tell you something is wrong.

**Unknown keys with suggestions:**
```javascript
// What you wrote:
{ block: MyBlock, conditon: [{ type: "user" }] }

// Error message:
[Blocks] Invalid block entry at blocks[0] for outlet "homepage-blocks":
Unknown entry key: "conditon" (did you mean "conditions"?).
Valid keys are: block, args, children, conditions, containerArgs, classNames.

Location:
└─ [0] MyBlock
   └─ conditon  ← error here

Context:
{
  block: <MyBlock>,
  conditon: [ // <-- error here
    { ... }
  ],
}
```

**Type mismatches with actual values:**
```javascript
// What you wrote:
{ type: "user", minTrustLevel: "2" }  // String, not number

// Error message:
[Blocks] BlockUserCondition: `minTrustLevel` must be a number between 0 and 4.
```

**Logical impossibilities caught early:**
```javascript
// What you wrote:
{ type: "user", minTrustLevel: 4, maxTrustLevel: 2 }

// Error message:
[Blocks] BlockUserCondition: `minTrustLevel` (4) cannot be greater than
`maxTrustLevel` (2). No user can satisfy this condition.
```

**Unknown condition types:**
```javascript
// What you wrote:
{ type: "usr", admin: true }

// Error message:
[Blocks] Unknown condition type: "usr" (did you mean "user"?).
Available types: route, user, setting, viewport, outletArg
```

**Conflicting options:**
```javascript
// What you wrote:
{ type: "setting", name: "badges", enabled: true, equals: false }

// Error message:
[Blocks] BlockSettingCondition: Cannot use multiple condition types together.
Use only one of: `enabled`, `equals`, `includes`, `contains`, or `containsAny`.
```

Registration-time errors catch problems before your app even boots. Duplicate names, missing namespaces, or format violations all surface immediately:

```javascript
// Duplicate block name
[Blocks] Block "theme:my-theme:banner" is already registered.
Each block name must be unique across all plugins and themes.
Previously registered at: your-theme/pre-initializers/register.js:12

// Missing namespace (plugin)
[Blocks] Plugin blocks must use the "namespace:block-name" format.
Got: "banner"
Expected format: "your-plugin:banner"

// Missing namespace (theme)
[Blocks] Theme blocks must use the "theme:namespace:block-name" format.
Got: "my-banner"
Expected format: "theme:your-theme:my-banner"
```

Args validation catches schema mismatches when `renderBlocks()` is called—missing required args, wrong types, or typos:

```javascript
// Missing required arg
[Blocks] Block "my-block" at blocks[0]:
Required arg "title" was not provided.

// Unknown arg (with suggestion)
[Blocks] Block "my-block" at blocks[0]:
Unknown arg "tite" (did you mean "title"?).
Declared args: title, subtitle, variant

// Type mismatch
[Blocks] Block "my-block" at blocks[0]:
Arg "count" expects type "number", got "string".
Value: "5" (string)
Hint: Remove quotes to pass a number: { count: 5 }

// Array item type mismatch
[Blocks] Block "my-block" at blocks[0]:
Arg "tags" expects array of "string", but item at index 2 is "number".
Value: ["a", "b", 123]
```

Outlet configuration validates that blocks can render where you're placing them:

```javascript
// Block denied in outlet
[Blocks] Block "theme:my-theme:hero" cannot render in outlet "sidebar-blocks":
Denied by deniedOutlets pattern "sidebar-*".

// Second renderBlocks call
[Blocks] Outlet "homepage-blocks" is already configured.
First configured by: my-theme/api-initializers/layout.js:8
Attempted again by: another-plugin/api-initializers/setup.js:15
Only one caller can configure an outlet.
```

Constraint errors catch violations of cross-arg rules—"provide at least one of these" or "these must go together":

```javascript
// atLeastOne violation
[Blocks] Block "featured-list" at blocks[0]:
At least one of "categoryId", "tagName" must be provided, but got none.

// exactlyOne violation (both provided)
[Blocks] Block "featured-list" at blocks[0]:
Exactly one of "categoryId", "tagName" must be provided, but got both.

// allOrNone violation
[Blocks] Block "image-block" at blocks[0]:
Args "width", "height" must be provided together or not at all.
Got: width=100, height=undefined
```

Container relationships are validated too—missing metadata, schema mismatches, or uniqueness violations:

```javascript
// Missing containerArgs
[Blocks] Block "tab-panel" at blocks[0].children[1]:
Parent container "tabs-container" requires containerArgs, but none provided.
Required fields: name (string)

// containerArgs without childArgs schema
[Blocks] Block "simple-panel" at blocks[0].children[0]:
containerArgs provided but parent "group" has no childArgs schema.
Remove containerArgs or add childArgs schema to parent.

// Duplicate unique value
[Blocks] Duplicate value "settings" for containerArgs.name in children of "tabs-container".
Found at children[0] and children[2].
The "name" field is marked as unique and must have distinct values.
```

### Validation Feedback

Validation happens at registration time when possible, giving you immediate feedback rather than runtime surprises.

**Source-mapped stack traces:**

When an error occurs, the stack trace points to your code, not internal block machinery:

```javascript
// Error shows:
at renderBlocks (your-theme/api-initializers/configure-blocks.js:15:3)
// Not:
at validateBlockConditions (discourse/lib/blocks/-internals/validation/layout.js:400:1)
```

This is achieved via `captureCallSite()` which excludes internal frames. Note that this API isn't available in all browsers—we provide cleaner stack traces when we can, but you'll still get useful error messages regardless.

Nested structures can be tricky to debug. The system helps here too.

**Condition path tracking:**

Errors in nested conditions include the full path:

```javascript
// Error in deeply nested condition:
[Blocks] Invalid conditions for block "my-block":
Condition type "route": unknown arg "querParams" (did you mean "queryParams"?).

Location: blocks[0].conditions.any[0].not.querParams

Context:
conditions: {
  any: [
    {
      not: {
        type: "route",
        querParams: { ... }, // <-- error here
      }
    },
    ...
  ]
}
```

Good errors help you fix problems. But the best experience is not needing to learn everything upfront.

### Simple by Default

The API balances simplicity for common cases with power for advanced use:

**Minimal configuration:**
```javascript
// Just show a block
{ block: WelcomeBanner }
```

**Add args when needed:**
```javascript
// Pass data to the block
{ block: WelcomeBanner, args: { title: "Hello" } }
```

**Add conditions when needed:**
```javascript
// Show conditionally
{
  block: WelcomeBanner,
  args: { title: "Hello" },
  conditions: [{ type: "user", loggedIn: true }]
}
```

**Add complex logic when needed:**
```javascript
// Complex conditional rendering
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

Start simple, add complexity only when you need it. You don't have to master conditions to render a block, and you don't have to master combinators to use a single condition. For complete condition syntax, see **Section 3: Show This, Hide That**.

So far we've focused on what happens when things go wrong. But what about when things *seem* fine but aren't working as expected?

---

## 6. Your Debugging Toolkit

The Blocks API includes a suite of visual and console-based tools to help you understand what's happening at runtime—which blocks rendered, which conditions passed or failed, and why.

### What's in the Toolkit

The toolkit includes four complementary tools—each designed to answer a different debugging question. Console Logging tells you *why* conditions passed or failed by showing the full evaluation in your browser's console. Visual Overlay shows you *where* blocks are rendered by adding clickable badges to the page. Outlet Boundaries reveals the outlets themselves, even when they're empty or have no visible blocks. And Ghost Blocks show what's hidden and why, appearing as dashed placeholders where blocks would render if their conditions passed.

| Tool | What it does | How to enable |
|------|--------------|---------------|
| **Console Logging** | Logs condition evaluations to browser console | Toggle "Block Debug" in toolbar |
| **Visual Overlay** | Shows block boundaries with badges and tooltips | Toggle "Block Overlay" in toolbar |
| **Outlet Boundaries** | Shows outlet boundaries even when empty | Toggle "Outlet Boundaries" in toolbar |
| **Ghost Blocks** | Shows hidden blocks as dashed placeholders | Enabled with Visual Overlay |

### Accessing the Tools

The debug tools live in the dev tools toolbar on the left side of the screen. Click the Block Debug button to reveal a dropdown with three toggleable options:

```
┌─────────────────────────────────┐
│ ☐ Console Logging              │
│ ☐ Visual Overlay               │
│ ☐ Outlet Boundaries            │
└─────────────────────────────────┘
```

The button icon highlights when any option is enabled, so you can tell at a glance whether debugging is active.

> :bulb: **Screenshot opportunity:** The dev tools toolbar with Block Debug dropdown expanded.

**Development vs Production:**

These tools work in both environments. In development builds, the toolbar is loaded and visible by default. In production, you'll need to enable it from the console:

```javascript
enableDevTools()   // stores preference, reloads page
disableDevTools()  // removes preference, reloads page
```

A few minor things differ between environments: production builds suppress some development-only warnings (like hints about unknown outlet patterns), and lazy-loaded blocks are resolved on-demand rather than eagerly. But the debugging tools themselves work identically once enabled.

> :warning: Debug mode adds performance overhead. Use for debugging, not routine production use.

### Console Logging

Toggle this on and open your browser's DevTools console. Every time a block renders (or doesn't), you'll see a collapsible log entry showing exactly what happened:

```
▼ [Blocks] ✓ RENDERED hero-banner in homepage-blocks
    ✓ AND (2 conditions)
      ✓ user { loggedIn: true }
      ✓ route { pages: ["DISCOVERY_PAGES"] }

▼ [Blocks] ✗ SKIPPED admin-banner in homepage-blocks
    ✗ AND (2 conditions)
      ✗ user { admin: true }
        actual: false, required: true
      ✓ route { pages: ["DISCOVERY_PAGES"] }
```

Green checkmarks (✓) mean a condition passed, red X marks (✗) mean it failed. When debug logging is enabled, the system evaluates *all* conditions—even after one fails—so you get the complete picture.

When something doesn't match, the logs show you both the actual value and what you configured, making it easy to spot the mismatch. The system also warns you about type mismatches—like when your condition expects a string but the actual value is `undefined`:

```
[Blocks] ✗ SKIPPED my-block in homepage-blocks
  ├─ ✗ route
  │  └─ ✗ queryParams: filter ⚠ type mismatch: actual is undefined, condition specifies string
  │     { actual: undefined, configured: "solved" }
```

These type mismatch warnings are particularly helpful for catching bugs where query params aren't present or have unexpected types.

### Visual Overlay

This is where things get visual. Enable it and every rendered block gets an orange badge in its top-left corner showing the block name:

```
┌─────────────────────────────────────────┐
│ 🧊 hero-banner                          │
├─────────────────────────────────────────┤
│                                         │
│     [Block content appears here]        │
│                                         │
└─────────────────────────────────────────┘
```

Click a badge and you'll get a tooltip with everything you need to know about that block: where it's rendering, which conditions were checked (and whether they passed), what arguments were passed in, and what outlet args are available.

```
┌─────────────────────────────────────────┐
│ 🧊 hero-banner in homepage-blocks       │
│ ─────────────────────────────────────── │
│ Status: RENDERED ✓                      │
│                                         │
│ Conditions (passed):                    │
│   ✓ AND                                 │
│     ✓ user { loggedIn: true }           │
│     ✓ route { pages: [...] }            │
│                                         │
│ Arguments:                              │
│   @title: "Welcome"                     │
│   @ctaText: "Get Started"               │
│                                         │
│ Outlet Args:                            │
│   @outletArgs.topic: Topic {...}        │
└─────────────────────────────────────────┘
```

> :bulb: **Screenshot opportunity:** A rendered block with badge and expanded tooltip.

### Ghost Blocks

Ghost blocks are enabled automatically with the Visual Overlay. They show you where blocks *would* render if their conditions had passed—a red dashed outline with diagonal stripes marking the spot:

```
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
  🧊 admin-banner (hidden)
│                                         │
      ╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
│     ╱╱╱╱ (diagonal stripes) ╱╱╱╱       │
      ╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
│                                         │
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
```

Click a ghost's badge and the tooltip explains why it's hidden:

```
┌─────────────────────────────────────────┐
│ 🧊 admin-banner in homepage-blocks      │
│ ─────────────────────────────────────── │
│ Status: HIDDEN ✗                        │
│                                         │
│ Reason: Conditions failed               │
│                                         │
│ Conditions (failed):                    │
│   ✗ AND                                 │
│     ✗ user { admin: true }              │
│     ─ route { ... } (not evaluated)     │
└─────────────────────────────────────────┘
```

Different reasons get different explanations: "conditions failed" for regular blocks, "no visible children" for containers whose children all failed, and "not registered" for optional blocks that reference uninstalled plugins.

For containers hidden because none of their children passed, the ghost shows nested ghosts for each child—so you can see exactly which children failed and why.

> :bulb: **Screenshot opportunity:** A ghost block with expanded tooltip showing why it's hidden.

### Outlet Boundaries

The third toggle—Outlet Boundaries—helps you see where outlets *are*, even when they're empty or have no visible blocks. Enable it and every outlet gets an amber dashed border with a badge showing its name and block count:

```
┌─────────────────────────────────────────┐
│ 🧊🧊 homepage-blocks (3 blocks)         │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤
│                                         │
│     [Rendered blocks appear here]       │
│                                         │
└─────────────────────────────────────────┘
```

This is especially useful when you're not sure if a `<BlockOutlet>` even exists on the current page, or when you're trying to figure out where a particular outlet renders relative to other content.

> :bulb: **Screenshot opportunity:** An outlet with amber dashed boundary and badge showing block count.

Now that you know what the tools look like, let's talk about *when* to use them.

### Debugging Workflows

**"I can't see my block"**

Start by figuring out whether the block is being skipped or not evaluated at all.

1. Enable **Console Logging** in dev tools
2. Navigate to the page where the block should appear
3. Look for your block in the console:
   - `✗ SKIPPED` — Your conditions are the issue; check which one failed
   - Not logged at all — Block not registered or outlet not configured

If you see SKIPPED, dig into the condition tree. If you don't see the block at all, it's a configuration problem. Either way, the visual tools help narrow it down:

4. Enable **Visual Overlay** and **Outlet Boundaries**
5. Find the outlet where your block should render
6. Check what appears: a ghost means conditions failed; nothing at all means the block isn't configured for this outlet

**"My condition isn't working"**

The console logs show you exactly what's being evaluated and why it failed.

1. Enable **Console Logging**
2. Expand the log for your block
3. Check the condition tree — is the condition type correct? Are the arguments what you expect? Look for type mismatch warnings.

Route conditions are particularly tricky because URLs and page types can be subtle:

4. For route conditions, verify the current URL matches what you expect, that page types are resolving correctly (`CATEGORY_PAGES` vs the actual category page you're on), and that any query params you're checking are actually present.

**"I'm not sure what's happening"**

When you're lost, turn on everything and observe.

1. Enable all debug tools
2. Open browser DevTools console
3. Navigate through the app and watch which blocks render or skip on each page, what conditions are evaluated, and how actual values compare to what you configured

The visual overlay gives you interactive access to block details:

4. Click on block badges to inspect what arguments were passed, what outlet args are available, and the full condition specification

### State Persistence

Debug tool settings are saved to sessionStorage:
- Survives page refreshes
- Resets on browser restart
- Per-tab independent state

This means you can enable debugging, navigate around, and the tools stay enabled.

### Using Tools Together

Each tool provides different information. Use them in combination for comprehensive debugging:

| Tool | Best For | Complements |
|------|----------|-------------|
| Console Logging | Seeing *why* conditions pass/fail | Visual Overlay (to see *which* blocks) |
| Visual Overlay | Finding blocks visually | Console Logging (to see condition details) |
| Outlet Boundaries | Confirming outlets exist | Visual Overlay (to see what's inside) |
| Ghost Blocks | Seeing hidden blocks | Console Logging (to see failure reasons) |

**Recommended workflow:**

1. **Start with Outlet Boundaries** - Confirm the outlet exists where you expect
2. **Enable Visual Overlay** - See what's rendering (or what ghosts appear)
3. **Enable Console Logging** - Understand the condition evaluation
4. **Check tooltips** - Verify args and outlet args are correct

### Tips for Effective Debugging

**Identifying configuration vs condition issues:**

- Block not in console at all → Registration or layout configuration issue
- Block logged as SKIPPED → Condition issue (check which failed)
- Block logged as RENDERED but not visible → CSS or DOM issue (not blocks)

**Common debugging scenarios:**

| Symptom | Check This |
|---------|------------|
| Block missing | Is outlet boundary visible? Is block in console logs? |
| Ghost but expected visible | Expand console log, check which condition failed |
| Visible but expected hidden | Check if all conditions are present in config |
| Works locally, not in prod | Are debug tools enabled? Check production build |

**Using the Args Table:**

Clicking rows in the Arguments or Outlet Args tables saves values to global console variables:

```javascript
// After clicking @title row in tooltip:
arg1 // → "Welcome"

// After clicking @outletArgs.topic row:
arg2 // → Topic { id: 123, title: "...", ... }

// You can now inspect in console:
arg2.category
arg2.user.username
```

This is particularly useful for inspecting complex objects like topics, users, or categories that are passed through outlet args.

### Integration with Browser DevTools

The Blocks API debug tools complement browser DevTools:

**Using with Elements panel:**
1. Enable Visual Overlay
2. Click a block badge
3. Right-click tooltip → "Inspect Element"
4. Now you're inspecting the block's DOM node

**Using with Console panel:**
1. Enable Console Logging
2. Expand a block's log group
3. Click object references to inspect full objects

**Using with Network panel:**
- Monitor lazy-loaded block imports
- Check if factory functions trigger network requests
- Verify block chunks load correctly

When blocks don't appear where you expect, the debugging tools help you see what's happening. But sometimes you want to understand *why* the system behaves the way it does—or you're working on the Blocks API itself and need to know how the pieces connect.

---

## 7. Under the Hood

Most developers never need to look here. The public API—`@block`, `registerBlock`, `renderBlocks`, `<BlockOutlet>`—handles everything you need for building with blocks. But if you're curious about the machinery, debugging something unusual, or contributing to the Blocks API itself, this section explains what happens behind the scenes.

### The Blocks Service

The `blocks` service is your window into the block system at runtime. While most block work happens declaratively through configuration, sometimes you need to query the system programmatically—checking if a plugin's blocks are available, listing what's registered for debugging, or building developer tools.

Inject it like any Ember service:

```javascript
import { service } from "@ember/service";

class MyComponent extends Component {
  @service blocks;

  get availableBlocks() {
    return this.blocks.listBlocksWithMetadata();
  }
}
```

The service exposes several methods for introspection. The most commonly used is `hasBlock()`, which checks whether a block name is registered:

```javascript
// Check before referencing a plugin's block
if (this.blocks.hasBlock("discourse-analytics:stats-panel")) {
  // Safe to use the block
}
```

For more detailed information, `listBlocksWithMetadata()` returns an array of objects describing every registered block:

```javascript
this.blocks.listBlocksWithMetadata()
// Returns:
// [
//   {
//     name: "theme:my-theme:banner",
//     shortName: "banner",
//     namespace: "theme:my-theme",
//     type: "theme",
//     isContainer: false,
//     metadata: {
//       description: "A promotional banner",
//       args: { title: { type: "string", required: true } },
//       // ... other schema properties
//     }
//   },
//   // ... more blocks
// ]
```

This is particularly useful for building admin interfaces that display available blocks, or for debugging tools that need to show what's registered. The metadata includes everything from the `@block()` decorator—description, args schema, constraints, outlet restrictions, and more.

The service is intentionally read-only. You can't register blocks or modify the registry through it—that happens through the plugin API during initialization. The service simply provides a safe way to query what exists.

### The Block Registry

Behind the service sits the block registry—a collection of Maps that track everything about registered blocks. You don't need to memorize these internals for everyday block development, but understanding the structure helps when you're debugging something unusual—like figuring out why a lazy-loaded block isn't resolving, or why two plugins seem to be conflicting over a namespace.

**The Core Data Structures**

The registry maintains several interconnected maps:

The **primary registry** maps block names to their entries. Each entry is either a component class (for eagerly-loaded blocks) or a factory function (for lazy-loaded blocks):

```javascript
// Conceptually:
blockRegistry = Map {
  "theme:my-theme:banner" => BannerComponent,
  "discourse-analytics:stats-panel" => () => import("./stats-panel"),
  "group" => GroupComponent,
  // ...
}
```

The **factory cache** stores resolved classes for lazy-loaded blocks. When a factory function is called and its Promise resolves, the resulting class is cached here so subsequent uses don't trigger another async load:

```javascript
// After first resolution:
factoryCache = Map {
  "discourse-analytics:stats-panel" => StatsPanelComponent,
}
```

The **pending resolutions** map tracks in-flight Promise resolutions. If two parts of the app try to resolve the same lazy block simultaneously, they share the same Promise rather than triggering duplicate loads:

```javascript
// During resolution:
pendingResolutions = Map {
  "discourse-analytics:stats-panel" => Promise<StatsPanelComponent>,
}
```

The **failed resolutions** set remembers which factories have failed. This prevents infinite retry loops—if a lazy-loaded block's import fails (maybe the plugin is disabled or the file doesn't exist), the system won't keep trying:

```javascript
failedResolutions = Set {
  "missing-plugin:broken-block",
}
```

**The Freeze Mechanism**

The registry has two states: unfrozen and frozen. During application boot, pre-initializers run with the registry unfrozen—this is when all `registerBlock()` calls must happen. After the `freeze-block-registry` initializer runs, the registry freezes and no more registrations are allowed.

This two-phase design serves several purposes. It ensures all blocks are available before any `renderBlocks()` calls configure layouts. It makes the set of available blocks deterministic—you can't have blocks appearing mid-session. And it catches registration timing errors early with clear error messages rather than mysterious runtime failures.

If you try to register a block after the freeze:

```javascript
// In an api-initializer (too late!):
api.registerBlock(MyBlock);
// Error: api.registerBlock() was called after the block registry was frozen.
// Block registration must happen in pre-initializers that run before "freeze-block-registry".
```

**Namespace Enforcement**

The registry also tracks which source (plugin or theme) registered each namespace. This prevents naming conflicts where two plugins might accidentally use the same block name.

When you register `"my-plugin:banner"`, the registry records that the `my-plugin` namespace belongs to your plugin. If another plugin later tries to register `"my-plugin:other-block"`, it fails—that namespace is already claimed:

```javascript
// Plugin A registers:
api.registerBlock(Banner);  // "my-plugin:banner" - claims "my-plugin" namespace

// Plugin B tries:
api.registerBlock(OtherBlock);  // "my-plugin:other" - ERROR: namespace conflict
```

This enforcement happens at registration time, so you'll see the error immediately during development rather than encountering mysterious behavior in production.

### The Preprocessing Pipeline

When a `<BlockOutlet>` component renders, it triggers a preprocessing pipeline that transforms the layout configuration into renderable components. This happens on every render, but the system is designed to be efficient through caching and short-circuit evaluation.

**Step 1: Layout Retrieval**

The outlet looks up its layout configuration from the outlet registry. If no layout was configured via `renderBlocks()`, the outlet renders nothing (or just its `:before`/`:after` named blocks if provided). The layout is an array of block entries—the same structure you passed to `renderBlocks()`.

**Step 2: Block Resolution**

Each block entry needs its block reference resolved to an actual component class. This handles the different ways blocks can be referenced:

For **class references** (when you imported and passed the class directly), resolution is immediate—the class is already available.

For **string references** (`"my-plugin:banner"`), the system looks up the name in the registry. If not found and the reference isn't optional (no `?` suffix), an error is thrown.

For **factory entries** (lazy-loaded blocks), the system checks the factory cache first. On cache hit, it uses the cached class. On cache miss, it calls the factory function, waits for the Promise to resolve, caches the result, and continues. During resolution, the pending resolutions map prevents duplicate concurrent loads.

```javascript
// Resolution flow for lazy-loaded block:
1. Check factoryCache → miss
2. Check pendingResolutions → miss
3. Call factory(), store Promise in pendingResolutions
4. Await Promise
5. Store result in factoryCache
6. Remove from pendingResolutions
7. Return resolved class
```

**Step 3: Condition Evaluation**

With all blocks resolved, the system evaluates conditions to determine visibility. This happens bottom-up—children are evaluated before their parents—because container visibility depends on having at least one visible child.

For each block entry:
1. Evaluate the entry's own conditions (if any)
2. If it's a container with children, recursively process children first
3. For containers, check if any child is visible
4. Mark the entry visible or hidden, recording the reason if hidden

The evaluation creates a parallel structure of "processed entries" that include the original configuration plus computed visibility state.

**Step 4: Component Creation**

For visible blocks, the system creates curried components. "Currying" in this context means pre-binding the component's args—instead of passing `<MyBlock @title="Hello" @count={{5}} />` in a template, the system creates a version of `MyBlock` that already has those args baked in. This is what actually gets rendered in the template. The currying captures:

- The block's declared args from the layout configuration
- System args like `@outletName`
- Outlet args from the `<BlockOutlet>` component
- For containers: the processed children array

**Step 5: Ghost Generation (Debug Mode)**

When visual overlay debugging is enabled, hidden blocks don't just disappear—they become "ghost" placeholders. The system creates lightweight placeholder components that render as dashed outlines with badges explaining why the block is hidden.

Ghosts preserve their position in the layout so you can see where blocks *would* appear if their conditions passed. This is invaluable for debugging visibility issues.

### Validation Internals

The Blocks API validates at multiple points during the application lifecycle. You don't need to memorize this sequence, but knowing the general flow helps when tracking down a tricky error—especially when you're not sure whether an error is from your decorator, your pre-initializer, or your layout configuration.

**Decoration Time**

When the `@block()` decorator executes (as your JavaScript loads), it performs immediate validation:

- Block name format (correct namespace pattern for plugins/themes)
- Args schema structure (valid types, no conflicting options)
- Constraint definitions (no incompatible constraints, no vacuous constraints due to defaults)
- Outlet patterns (no conflicts between `allowedOutlets` and `deniedOutlets`)
- Container-specific options (`containerClassNames` only on containers, `childArgs` only on containers)

These errors appear in the console as soon as the file loads, often before the application finishes booting. They're the earliest possible feedback.

**Registration Time**

When `registerBlock()` is called, additional validation occurs:

- Duplicate name detection (with source tracking for helpful error messages)
- Namespace ownership verification
- Registry frozen check

Registration errors point to your pre-initializer code with information about what was already registered and where.

**Layout Configuration Time**

When `renderBlocks()` is called, the system validates the entire layout:

- Block existence (all referenced blocks must be registered, unless optional)
- Outlet validity (the outlet name must be registered)
- Outlet ownership (no duplicate `renderBlocks()` calls for the same outlet)
- Entry key validation (no typos in property names)
- Args validation against schemas (types, required fields, constraints)
- Condition validation (known types, valid args for each condition type)
- Container relationships (`children` only on containers, `containerArgs` matches parent's `childArgs`)

This is where most developer errors surface. The validation is thorough because fixing errors at boot time is far better than mysterious runtime behavior.

**Render Time**

By the time blocks actually render, most validation has already happened. Render-time checks are minimal:

- Authorization symbol verification (blocks can only render through proper channels)
- Lazy block resolution (factory functions are called, imports are loaded)

If a lazy-loaded block's import fails at render time, the error is caught and reported, and the block is marked as failed to prevent retry loops.

### Condition Discovery and Instantiation

Conditions are more than just data objects—they're backed by classes that know how to evaluate themselves. Understanding how conditions are discovered, instantiated, and invoked explains some of the system's design choices.

**The Condition Type Registry**

Like blocks, condition types have their own registry. Built-in types (`user`, `route`, `setting`, `viewport`, `outletArg`) are registered by core during the `freeze-block-registry` initializer. Custom conditions must be registered in pre-initializers that run before this freeze.

Each condition type is a class decorated with `@blockCondition()`:

```javascript
@blockCondition({
  type: "user",
  args: {
    loggedIn: { type: "boolean" },
    admin: { type: "boolean" },
    // ...
  },
})
export class BlockUserCondition extends BlockCondition {
  @service currentUser;

  evaluate(args, context) {
    // Return true if condition passes
  }
}
```

The decorator captures the type name and args schema, similar to how `@block()` works for blocks.

**Condition Instantiation**

When the preprocessing pipeline evaluates conditions, it needs instances of condition classes that have access to Ember services. The system creates one instance of each condition type per evaluation context, setting the Ember owner so service injection works:

```javascript
// Conceptually:
const userCondition = new BlockUserCondition();
setOwner(userCondition, applicationInstance);
// Now userCondition.currentUser is injected
```

These instances are reused across all condition evaluations within the same preprocessing pass, so a layout with 20 user conditions doesn't create 20 instances—just one that's called 20 times with different args.

**The Evaluation Context**

When `evaluate()` is called, it receives two arguments: the condition's args (from the layout configuration) and an evaluation context containing:

- `outletArgs` - Data passed from the template via `@outletArgs`
- `outletName` - The outlet being rendered

This context allows conditions to access runtime data without hardcoding assumptions about where they'll be used.

**The evaluate() Contract**

Condition evaluation must be synchronous. The `evaluate()` method returns a boolean immediately—no Promises, no async/await. This constraint exists because condition evaluation happens during the render cycle, and async operations would complicate Ember's rendering model.

If your condition needs async data, the pattern is to fetch it elsewhere (in a route, a service, or a component's constructor) and pass it through outlet args. The condition then just checks the already-available data.

```javascript
// Instead of this (won't work):
evaluate(args) {
  const data = await fetch('/api/feature-flags');  // Can't await!
  return data.includes(args.flag);
}

// Do this:
evaluate(args, context) {
  // Data was fetched elsewhere and passed through outlet args
  return context.outletArgs.featureFlags?.includes(args.flag);
}
```

### The Authorization Symbol System

The final piece of the puzzle is how the system prevents unauthorized block rendering. You might wonder: if blocks are just Glimmer components, what stops someone from using them directly in a template?

The answer is a private symbol system. When blocks are defined, they receive a reference to a secret symbol that's not exported from any public module. At construction time, blocks verify they received this symbol through a special arg—if not, they throw an error.

**How It Works**

The `@block()` decorator adds constructor logic that checks for an authorization arg:

```javascript
// Simplified conceptual view:
constructor(owner, args) {
  if (args.__blockAuth !== BLOCK_SYMBOL) {
    throw new Error("Blocks can only be rendered through BlockOutlet");
  }
  super(owner, args);
}
```

When the preprocessing pipeline creates curried components it includes this secret symbol in the args. Direct template usage (`<MyBlock />`) doesn't include the symbol, so the constructor throws.

**The Chain of Trust**

Container blocks pass their own authorization symbol to children, creating a chain of trust. But what authorizes the root? `<BlockOutlet>` is itself a block (decorated with `@block("block-outlet", { container: true })`), but it has special handling that allows it to bypass the check and initiate the chain.

This design ensures:
- Blocks only render through the official system
- Conditions are always evaluated (can't be bypassed)
- Layout configuration is always respected
- Plugin developers can't accidentally misuse blocks

**Why Not Just Documentation?**

You might think "just tell people not to use blocks directly." But plugin ecosystems involve many developers with varying familiarity with the codebase. A runtime enforcement mechanism catches mistakes that documentation warnings miss—and the error message explains exactly what to do instead.

Now that you understand how the pieces fit together, let's apply this knowledge to build something real.

---

## 8. Putting It Together

The tutorials in this section build on everything we've covered—blocks, conditions, containers, and the patterns that make them work together. Each one adds complexity, showing how the concepts combine in practice.

### Tutorial 1: A Simple Promotional Banner

Let's build a banner that shows on the homepage for non-admin users.

**Step 1: Create the block component**

```javascript
// themes/my-theme/javascripts/discourse/blocks/promo-banner.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks/block-outlet";

@block("theme:my-theme:promo-banner", {
  description: "A promotional banner with customizable message and call-to-action",
  args: {
    message: { type: "string", required: true },
    linkUrl: { type: "string" },
    linkText: { type: "string", default: "Learn more" },
    dismissible: { type: "boolean", default: true },
  },
})
export default class PromoBanner extends Component {
  <template>
    <div class="promo-banner">
      <p class="promo-banner__message">{{@message}}</p>
      {{#if @linkUrl}}
        <a href={{@linkUrl}} class="promo-banner__link">{{@linkText}}</a>
      {{/if}}
      {{#if @dismissible}}
        <button class="promo-banner__dismiss" aria-label="Dismiss">×</button>
      {{/if}}
    </div>
  </template>
}
```

> :bulb: Use the BEM naming convention for CSS classes (explained in Section 1): `.block-name`, `.block-name__element`, `.block-name--modifier`. This keeps styles scoped and predictable.

**Step 2: Register the block**

```javascript
// themes/my-theme/javascripts/discourse/pre-initializers/register-blocks.js
import { withPluginApi } from "discourse/lib/plugin-api";
import PromoBanner from "../blocks/promo-banner";

export default {
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(PromoBanner);
    });
  },
};
```

**Step 3: Configure where and when it renders**

```javascript
// themes/my-theme/javascripts/discourse/api-initializers/configure-blocks.js
import { apiInitializer } from "discourse/lib/api";
import PromoBanner from "../blocks/promo-banner";

export default apiInitializer((api) => {
  api.renderBlocks("homepage-blocks", [
    {
      block: PromoBanner,
      args: {
        message: "Welcome to our community! Check out the getting started guide.",
        linkUrl: "/t/getting-started/1",
      },
      conditions: [
        { type: "route", pages: ["HOMEPAGE"] },
        { not: { type: "user", admin: true } },
      ],
    },
  ]);
});
```

**What we accomplished:**
- Block renders only on the custom homepage
- Block hides for admin users (they don't need the promo)
- Content is configurable via args (message, link)
- Dismissible by default

That covered the basics. Now let's use outlet args and route conditions to create context-aware layouts.

### Tutorial 2: Category-Specific Information Panels

Let's build an information panel system that shows different content based on which category the user is browsing. This example assumes a hypothetical `category-sidebar-blocks` outlet that provides `category` in its outlet args and appears on category pages.

**Step 1: Create a reusable info panel block**

```javascript
// themes/my-theme/javascripts/discourse/blocks/info-panel.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks/block-outlet";
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

Often you want to show one panel OR another based on context, not multiple panels simultaneously. The `first-match` container renders only its first visible child—perfect for "if X, else if Y, else Z" logic:

```javascript
// themes/my-theme/javascripts/discourse/api-initializers/category-panels.js
import { apiInitializer } from "discourse/lib/api";
import InfoPanel from "../blocks/info-panel";

export default apiInitializer((api) => {
  api.renderBlocks("category-sidebar-blocks", [
    {
      block: "first-match",
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

The `first-match` container evaluates children in order and renders only the first one whose conditions pass. In the support category, you see the "Need Help?" panel. In dev/plugins/themes categories, you see "Developer Resources." Everywhere else, the default "Welcome!" panel appears.

**Step 3: Add a conditional panel using outlet args**

The `first-match` container handles "show one of these" logic, but you can add other blocks alongside it. Let's add a rules panel that appears above the category-specific panel whenever the category has custom rules defined. This uses the `outletArg` condition to check data from the outlet:

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
      type: "outletArg",
      path: "category.custom_fields.has_rules",
      value: true,
    },
  },

  // Category-specific panel (first-match from Step 2)
  {
    block: "first-match",
    children: [
      // ... same children as Step 2
    ],
  },
]);
```

Now the layout can show up to two panels: the rules panel (if the category has rules) plus one category-specific panel from the `first-match` container.

**What we accomplished:**
- Created a reusable panel component for category sidebars
- Used `first-match` container for prioritized "if/else" rendering
- Combined multiple top-level blocks with different visibility logic
- Used route conditions with `params` to target specific categories
- Used `outletArg` condition to check category data from the outlet
- Combined `any` operator to match multiple categories with one condition
- Mixed route conditions with user conditions (staff-only)
- Provided a default fallback by omitting conditions on the last child

So far we've been working within a single theme or plugin. The real power of the Blocks API emerges when multiple plugins provide blocks and a theme composes them into a unified layout.

### Tutorial 3: Theme Dashboard from Plugin Blocks

Let's build a community dashboard where:
- **Plugins** register blocks (provide functionality)
- **Theme** calls `renderBlocks()` to compose the layout

This separation is intentional: plugins provide content, themes control presentation. Given a hypothetical `community-dashboard` outlet in core, here's how the pieces fit together.

**Plugin A: Analytics Plugin**

First, the analytics plugin creates and registers a stats panel block:

```javascript
// plugins/discourse-analytics/assets/javascripts/discourse/blocks/stats-panel.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks/block-outlet";

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

```javascript
// plugins/discourse-analytics/assets/javascripts/discourse/pre-initializers/register-blocks.js
import { withPluginApi } from "discourse/lib/plugin-api";
import StatsPanel from "../blocks/stats-panel";

export default {
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(StatsPanel);
    });
  },
};
```

**Plugin B: Tasks Plugin**

The tasks plugin provides a task list block:

```javascript
// plugins/discourse-tasks/assets/javascripts/discourse/blocks/task-list.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks/block-outlet";

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

```javascript
// plugins/discourse-tasks/assets/javascripts/discourse/pre-initializers/register-blocks.js
import { withPluginApi } from "discourse/lib/plugin-api";
import TaskList from "../blocks/task-list";

export default {
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(TaskList);
    });
  },
};
```

**Plugin C: Gamification Plugin**

The gamification plugin adds a leaderboard block:

```javascript
// plugins/discourse-gamification/assets/javascripts/discourse/blocks/leaderboard.gjs
import Component from "@glimmer/component";
import { block } from "discourse/blocks/block-outlet";

@block("discourse-gamification:leaderboard", {
  description: "Top contributors leaderboard",
  args: {
    count: { type: "number", default: 10 },
    period: { type: "string", default: "week" },
  },
})
export default class Leaderboard extends Component {
  <template>
    <div class="leaderboard">
      <h3 class="leaderboard__title">Top Contributors ({{@period}})</h3>
      <ol class="leaderboard__list">
        {{#each @outletArgs.leaders as |leader|}}
          <li class="leaderboard__entry">
            {{leader.username}} - {{leader.points}} pts
          </li>
        {{/each}}
      </ol>
    </div>
  </template>
}
```

```javascript
// plugins/discourse-gamification/assets/javascripts/discourse/pre-initializers/register-blocks.js
import { withPluginApi } from "discourse/lib/plugin-api";
import Leaderboard from "../blocks/leaderboard";

export default {
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(Leaderboard);
    });
  },
};
```

**Theme: Composing the Dashboard**

Now the theme brings everything together. It doesn't create blocks—it orchestrates them:

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

> :exclamation: Notice the `?` suffix on each block name (e.g., `"discourse-analytics:stats-panel?"`). This marks the block as **optional**. If the plugin isn't installed or is disabled, the block silently skips instead of throwing an error. This is essential when themes reference blocks from plugins that may or may not be present.

**What we accomplished:**
- Three plugins each provide focused, reusable blocks
- Theme controls layout and configuration without touching plugin code
- Optional blocks (`?` suffix) gracefully handle missing plugins
- Conditions are set by the theme based on its design requirements
- Plugins don't need to know about each other
- Adding a new plugin's block to the dashboard is just one more entry in `renderBlocks()`

That's the Blocks API in practice. What follows is the complete reference for when you need to look something up.

---

## 9. Quick Reference

You've made it through the concepts, seen how the pieces connect, and worked through the tutorials. Now you need a place to quickly look up that decorator option you can't quite remember, or check the exact syntax for a route condition. This section is that place—organized for fast lookup, but still readable when you need to refresh your memory on how things fit together.

### The Full API

The Blocks API surface is compact by design. You'll use these five methods and one decorator for nearly everything. Registration happens in pre-initializers (before the registry freezes), and layout configuration happens in api-initializers.

**The Plugin API methods** handle all registration and configuration:

```javascript
api.registerBlock(BlockClass)
api.registerBlock("name", () => import("./block"))
api.renderBlocks(outletName, layout)
api.registerBlockOutlet(outletName, options)
api.registerBlockConditionType(ConditionClass)
```

The first two register blocks—either by passing the class directly or by providing a factory function for lazy loading. The `renderBlocks()` call configures which blocks appear in an outlet and in what order. The last two are for advanced cases: creating custom outlets and custom condition types.

**The `@block` decorator** transforms a Glimmer component into a block:

```javascript
@block(name, options)

// Options:
{
  container: boolean,           // Can contain child blocks
  containerClassNames: string | string[] | ((args) => string),  // Custom CSS classes for container wrapper (container blocks only)
  description: string,          // Human-readable description
  args: { [key]: ArgSchema },   // Argument definitions
  childArgs: { [key]: ChildArgSchema },  // Schema for child-provided metadata (container blocks only)
  constraints: ConstraintSpec,  // Cross-arg validation rules
  validate: (args) => string | string[] | undefined,  // Custom validation
  allowedOutlets: string[],     // Glob patterns for allowed outlets
  deniedOutlets: string[],      // Glob patterns for denied outlets
}

// ArgSchema:
{
  type: "string" | "number" | "boolean" | "array" | "any",
  required?: boolean,
  default?: any,
  // For arrays:
  itemType?: "string" | "number" | "boolean",
  itemEnum?: string[] | number[] | boolean[],  // Restrict array items to specific values
  // For strings:
  pattern?: RegExp,
  minLength?: number,                           // Also for arrays
  maxLength?: number,                           // Also for arrays
  // For numbers:
  min?: number,
  max?: number,
  integer?: boolean,
  // For strings and numbers:
  enum?: string[] | number[],
}

// ConstraintSpec:
{
  atLeastOne?: string[],   // At least one must be provided
  exactlyOne?: string[],   // Exactly one must be provided
  allOrNone?: string[],    // All or none must be provided
  atMostOne?: string[],    // At most one may be provided (0 or 1)
  requires?: { [dependent: string]: string },  // Dependent arg requires another arg
}

// ChildArgSchema (extends ArgSchema):
{
  // Same properties as ArgSchema, plus:
  unique?: boolean,        // Enforce uniqueness across sibling children (primitives only)
}
```

Most blocks need only a handful of these options—a name, maybe some args, and perhaps outlet restrictions. The full schema is here when you need it.

**Block entries** are the objects you pass to `renderBlocks()`. Each entry describes one block in your layout:

```javascript
{
  block: BlockClass | "block-name" | "block-name?",  // Required
  args?: { [key]: any },           // Arguments passed to the block
  conditions?: ConditionSpec | ConditionSpec[],
  classNames?: string | string[],
  children?: BlockEntry[],         // Only for container blocks
  containerArgs?: { [key]: any },  // Metadata provided to parent container
}
```

> :bulb: Use string references (`"plugin:block-name"`) for blocks registered with factory functions. Factory functions should be declared in `registerBlock()`, not in the layout.

**Condition specifications** control when blocks appear. The syntax is designed to be readable—single conditions are just objects, arrays mean AND, and wrappers handle OR and NOT:

```javascript
// Single condition
{ type: "conditionType", ...args }

// AND (all must pass)
[condition1, condition2, ...]

// OR (at least one must pass)
{ any: [condition1, condition2, ...] }

// NOT (must fail)
{ not: condition }
```

These patterns nest arbitrarily deep, so you can express complex visibility rules declaratively. See Section 3 for examples combining multiple conditions.

### Configuration Options

Each condition type accepts different arguments. The tables below serve as a quick lookup—you'll find detailed explanations and examples back in Section 3, but these capture the essentials at a glance.

**Route conditions** match based on URL patterns or semantic page types:

#### Route Condition Args

| Arg | Type | Description |
|-----|------|-------------|
| `urls` | `string[]` | URL patterns to match (glob syntax) |
| `pages` | `string[]` | Page types to match (e.g., `["CATEGORY_PAGES"]`) |
| `params` | `object` | Page-specific params (only with `pages`) |
| `queryParams` | `object` | Query params to match (works with both) |

> :bulb: **Note:** Use `{ not: { type: "route", ... } }` to exclude URLs or page types.

**User conditions** check properties of the current user (or another user from outlet args via `source`). All properties use AND logic when combined:

| Arg | Type | Description |
|-----|------|-------------|
| `source` | `string` | Path to user in outlet args |
| `loggedIn` | `boolean` | Must be logged in/out |
| `admin` | `boolean` | Must be admin |
| `moderator` | `boolean` | Must be moderator |
| `staff` | `boolean` | Must be staff |
| `minTrustLevel` | `number` | Minimum trust level (0-4) |
| `maxTrustLevel` | `number` | Maximum trust level (0-4) |
| `groups` | `string[]` | Must be in one of these groups |

**Setting conditions** check site settings or custom settings objects (like theme settings). You can only use one comparison type per condition—pick `enabled`, `equals`, `includes`, `contains`, or `containsAny`:

| Arg | Type | Description |
|-----|------|-------------|
| `name` | `string` | Setting key (required) |
| `source` | `object` | Custom settings object |
| `enabled` | `boolean` | Setting is truthy/falsy |
| `equals` | `any` | Exact value match |
| `includes` | `array` | Value is in array |
| `contains` | `string` | List contains value |
| `containsAny` | `array` | List contains any value |

**Viewport conditions** respond to screen size and device capabilities. The breakpoints follow standard responsive design sizes (sm: 640px, md: 768px, lg: 1024px, xl: 1280px, 2xl: 1536px):

| Arg | Type | Description |
|-----|------|-------------|
| `min` | `string` | Minimum breakpoint |
| `max` | `string` | Maximum breakpoint |
| `mobile` | `boolean` | Mobile device only |
| `touch` | `boolean` | Touch device only |

**OutletArg conditions** check values from the template context. Use dot notation to navigate nested objects. Remember that `value` and `exists` are mutually exclusive—use one or the other:

| Arg | Type | Description |
|-----|------|-------------|
| `path` | `string` | Dot-notation path (required) |
| `value` | `any` | Value to match |
| `exists` | `boolean` | Property existence check |

### Troubleshooting Guide

Something not working? This section walks through the most common issues and how to diagnose them. Rather than jumping straight to solutions, we'll trace through the diagnostic process—the same approach you'd take with the debug tools.

#### Block not appearing

When a block doesn't show up where you expect it, the issue falls into one of four categories: registration, configuration, conditions, or the outlet itself.

Start by checking whether the block is **registered**. Open your browser console and look for errors during boot. If you see messages about unknown blocks or registration timing, your pre-initializer might be running after the registry freezes. Make sure it specifies `before: "freeze-block-registry"` in its export.

If registration looks fine, verify the **layout configuration**. Did you call `renderBlocks()` with the correct outlet name? The system validates outlet names and throws an error with a fuzzy-matched suggestion if the outlet doesn't exist. Enable the Outlet Boundaries debug tool to confirm the outlet exists and to see its name.

Next, check **conditions**. Enable Console Logging in the debug tools and look for your block in the output. If you see `✗ SKIPPED`, expand the log to see which condition failed. The debug output shows exactly what value was found versus what your condition expected.

Finally, confirm the **outlet is rendered** in the template. The `<BlockOutlet @name="...">` component must exist somewhere in the page's template hierarchy, and the name must match exactly what you passed to `renderBlocks()`.

#### Validation errors

Validation errors appear in the console during boot. They're designed to be actionable—read them carefully.

**"Unknown entry key"** means you have a typo in your block entry object. The valid keys are `block`, `args`, `conditions`, `classNames`, `children`, and `containerArgs`. The error message usually suggests what you meant.

**"Unknown condition type"** indicates either a typo in your condition's `type` field, or a custom condition that isn't registered. Check the spelling, and if it's a custom condition, verify it's registered in a pre-initializer before the registry freezes.

**"Block not registered"** appears when you reference a block that doesn't exist in the registry. Either the block's pre-initializer isn't running, it's running too late (after the freeze), or there's a typo in the block name. For optional blocks from plugins that might not be installed, add the `?` suffix to the name.

**"Cannot render in outlet"** means the block has `allowedOutlets` or `deniedOutlets` restrictions that exclude the outlet you're trying to use. Check the block's decorator options and adjust either the restrictions or your outlet choice.

#### Conditions not evaluating as expected

When conditions pass or fail unexpectedly, the Console Logging debug tool is your best friend.

**Type mismatches** are the most common culprit. The debug output warns you when types don't match—like comparing a string query param to a number. Query params are always strings, so `queryParams: { page: 1 }` won't match `?page=1` (the string "1"). Use `queryParams: { page: "1" }` instead.

**Page type confusion** happens when you expect `CATEGORY_PAGES` but you're actually on a different page type. The route condition checks semantic page types, not just URLs. Verify you're on the expected page type by checking the console output, which shows which page types matched.

**Undefined outlet args** occur when the template doesn't pass the expected data. Verify the `<BlockOutlet>` includes `@outletArgs={{hash topic=this.topic}}` or similar, and check that your condition's `path` exactly matches the structure of what's passed.

### FAQ: Advanced Troubleshooting

For edge cases and deeper issues, these answers address questions that come up after you've checked the basics.

**Q: My block renders in development but not in production. Why?**

A: Check these common causes:
1. **Bundle splitting** - Factory functions may fail if the import path is wrong in production builds. Verify the import path resolves correctly.
2. **Different site settings** - Production may have different settings that affect your conditions.

**Q: Console shows my condition passed, but the block isn't visible. What's happening?**

A: The block may be rendered but hidden by CSS. Check:
1. Is the block inside a container that's hidden? If a parent container's conditions are failing—child visibility doesn't help if the parent is hidden.
2. Is there CSS that's hiding the block's DOM element?
3. Is the block rendering empty content? (Check your template)

**Q: Two plugins both want to render blocks in the same outlet. How do I resolve this?**

A: Only one caller can configure an outlet with `renderBlocks()`. The solution is the intended pattern:
1. Both plugins should `registerBlock()` only (in pre-initializers)
2. The theme should call `renderBlocks()` to compose blocks from both plugins
3. Use optional blocks (`?`) in case either plugin is disabled

You need to control both plugins. Otherwise one of them will need to be disabled.

**Q: Can I dynamically change which blocks render after boot?**

A: No. Block layouts are configured at boot time and frozen. For dynamic visibility:
1. **Use conditions** - Blocks can appear/disappear based on reactive state
2. **Use outlet args** - Pass dynamic data that conditions can check
3. **Use multiple outlets** - Different outlets for different contexts

If you need truly dynamic layout changes, plugin outlets may be more appropriate.

### Testing API

Testing blocks requires the ability to register them outside the normal boot sequence—registries are frozen by the time your tests run. The `block-testing` module provides utilities that temporarily unfreeze registries, let you register test blocks and conditions, and then clean up afterward so tests don't interfere with each other.
```javascript
import { ... } from "discourse/tests/helpers/block-testing";
```

The utilities are organized by what they operate on. For **block registration**, you'll primarily use `withTestBlockRegistration()` which handles the unfreeze/freeze cycle for you:

- `withTestBlockRegistration(callback)` - Temporarily unfreeze registry for registration
- `registerBlock(BlockClass)` - Register a block class
- `registerBlockFactory(name, asyncFn)` - Register a lazy-loading factory
- `freezeBlockRegistry()` - Manually freeze the registry

When you need to **query the block registry** (useful for assertions or conditional test logic):

- `hasBlock(name)` - Check if block is registered
- `getBlockEntry(name)` - Get registry entry
- `isBlockFactory(name)` - Check if entry is a factory
- `isBlockResolved(name)` - Check if block is resolved
- `isBlockRegistryFrozen()` - Check frozen state
- `resolveBlock(ref)` - Async resolve block reference
- `tryResolveBlock(ref)` - Sync resolve attempt

For **outlet registration** (when testing custom outlets):

- `registerOutlet(name, options)` - Register custom outlet
- `freezeOutletRegistry()` - Freeze outlet registry

And the corresponding **outlet queries**:

- `isValidOutlet(name)` - Check if outlet is valid
- `getAllOutlets()` - Get all registered outlets
- `getCustomOutlet(name)` - Get custom outlet data
- `isOutletRegistryFrozen()` - Check frozen state

When testing **custom conditions**, you'll need similar registration utilities:

- `withTestConditionRegistration(callback)` - Temporarily unfreeze for registration
- `registerConditionType(ConditionClass)` - Register a condition type
- `freezeConditionTypeRegistry()` - Freeze condition registry

The **condition query** utilities help you verify registration and validate condition specs:

- `hasConditionType(type)` - Check if condition type is registered
- `isConditionTypeRegistryFrozen()` - Check frozen state
- `validateConditions(spec, types)` - Validate condition specification

For testing **debug tool behavior**, the module exposes a reactive interface:

- `debugHooks` - Reactive debug interface for testing debug mode behavior
- `DEBUG_CALLBACK` - Debug callback type constants

Finally, **reset utilities** ensure clean state between tests:

- `resetBlockRegistryForTesting()` - Reset all registries to initial state
- `setTestSourceIdentifier(id)` - Override source identifier for testing

**Debug Hooks Example:**

```javascript
import { debugHooks, DEBUG_CALLBACK } from "discourse/tests/helpers/block-testing";

// Reactive getters for checking debug state
debugHooks.isBlockLoggingEnabled   // boolean
debugHooks.isOutletBoundaryEnabled // boolean
debugHooks.isVisualOverlayEnabled  // boolean
debugHooks.loggerInterface         // logger object or null

// Set/get callbacks by key
debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG)
debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_LOGGING, () => true)
```

The `debugHooks` singleton provides reactive getters that automatically track dependencies. This means UI components using these values will re-render when debug settings change.

### Testing Strategies

Writing tests for blocks follows patterns you'll recognize from other Discourse testing, but with a few block-specific considerations. You need to register blocks before using them, you may need custom conditions for controlled testing, and you often want to verify visibility based on different states.

#### Unit Testing Custom Conditions

Custom conditions are classes with an `evaluate()` method—straightforward to unit test. Instantiate the condition directly, set the Ember owner for service injection, and call `evaluate()` with test arguments:

```javascript
import { getOwner, setOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import FeatureFlagCondition from "my-plugin/blocks/conditions/feature-flag";
import { validateConditions } from "discourse/tests/helpers/block-testing";

module("Unit | Condition | feature-flag", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.condition = new FeatureFlagCondition();
    setOwner(this.condition, getOwner(this));

    // Helper to validate through the infrastructure (handles schema + custom validation)
    this.validateCondition = (args) => {
      const conditionTypes = new Map([["feature-flag", this.condition]]);
      try {
        validateConditions({ type: "feature-flag", ...args }, conditionTypes);
        return null;
      } catch (error) {
        return error;
      }
    };
  });

  module("validate (through infrastructure)", function () {
    test("returns error for invalid flag format", function (assert) {
      const error = this.validateCondition({ flag: "INVALID-FLAG" });

      assert.notStrictEqual(error, null, "returns an error");
      assert.true(error?.message.includes("flag"), "error mentions flag");
    });

    test("passes valid configuration", function (assert) {
      const error = this.validateCondition({ flag: "my_feature" });
      assert.strictEqual(error, null);
    });
  });

  module("evaluate", function () {
    test("returns true when feature flag is enabled", function (assert) {
      this.condition.featureFlags = { isEnabled: () => true };

      const result = this.condition.evaluate({ flag: "my_feature", enabled: true });
      assert.true(result);
    });

    test("returns false when feature flag is disabled", function (assert) {
      this.condition.featureFlags = { isEnabled: () => false };

      const result = this.condition.evaluate({ flag: "my_feature", enabled: true });
      assert.false(result);
    });

    test("returns true when checking for disabled flag that is disabled", function (assert) {
      this.condition.featureFlags = { isEnabled: () => false };

      const result = this.condition.evaluate({ flag: "my_feature", enabled: false });
      assert.true(result);
    });
  });
});
```

#### Integration Testing Block Visibility

Test blocks with conditions using the test helpers from the registration module.

> :bulb: These test examples use hypothetical outlet names like `test-outlet` and `topic-outlet`. In tests, outlet names can be created on the fly—you don't need to register them separately.

```javascript
import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, { block } from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Block | my-banner", function (hooks) {
  setupRenderingTest(hooks);

  test("renders when conditions pass", async function (assert) {
    @block("test-banner", {
      args: { message: { type: "string" } },
    })
    class TestBanner extends Component {
      <template>
        <div class="test-banner">{{@message}}</div>
      </template>
    }

    // Register the block (synchronous, single callback parameter)
    withTestBlockRegistration(() => registerBlock(TestBanner));

    // Configure the layout using the plugin API
    withPluginApi((api) =>
      api.renderBlocks("test-outlet", [
        {
          block: TestBanner,
          args: { message: "Hello World" },
        },
      ])
    );

    await render(<template><BlockOutlet @name="test-outlet" /></template>);

    assert.dom(".test-banner").exists();
    assert.dom(".test-banner").hasText("Hello World");
  });

  test("does not render when conditions fail", async function (assert) {
    @block("conditional-banner")
    class ConditionalBanner extends Component {
      <template>
        <div class="conditional-banner">Should not appear</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(ConditionalBanner));
    withPluginApi((api) =>
      api.renderBlocks("conditional-outlet", [
        {
          block: ConditionalBanner,
          // This condition will fail for anonymous users
          conditions: { type: "user", admin: true },
        },
      ])
    );

    await render(<template><BlockOutlet @name="conditional-outlet" /></template>);

    assert.dom(".conditional-banner").doesNotExist();
  });
});
```

#### Testing with Custom Test Conditions

For complex condition testing, register custom test conditions:

```javascript
import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { BlockCondition, blockCondition } from "discourse/blocks/conditions";
import BlockOutlet, { block } from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  registerBlock,
  registerConditionType,
  withTestBlockRegistration,
  withTestConditionRegistration,
} from "discourse/tests/helpers/block-testing";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// Define test conditions at module scope (required for decorators)
@blockCondition({ type: "always-true", args: {} })
class AlwaysTrueCondition extends BlockCondition {
  evaluate() {
    return true;
  }
}

@blockCondition({ type: "always-false", args: {} })
class AlwaysFalseCondition extends BlockCondition {
  evaluate() {
    return false;
  }
}

module("Integration | Block | conditional rendering", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    // Register test conditions before each test
    withTestConditionRegistration(() => {
      registerConditionType(AlwaysTrueCondition);
      registerConditionType(AlwaysFalseCondition);
    });
  });

  test("renders when custom condition passes", async function (assert) {
    @block("custom-condition-block")
    class CustomConditionBlock extends Component {
      <template>
        <div class="custom-block">Rendered</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(CustomConditionBlock));
    withPluginApi((api) =>
      api.renderBlocks("custom-outlet", [
        {
          block: CustomConditionBlock,
          conditions: { type: "always-true" },
        },
      ])
    );

    await render(<template><BlockOutlet @name="custom-outlet" /></template>);

    assert.dom(".custom-block").exists();
  });

  test("hides when custom condition fails", async function (assert) {
    @block("hidden-block")
    class HiddenBlock extends Component {
      <template>
        <div class="hidden-block">Hidden</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(HiddenBlock));
    withPluginApi((api) =>
      api.renderBlocks("hidden-outlet", [
        {
          block: HiddenBlock,
          conditions: { type: "always-false" },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hidden-outlet" /></template>);

    assert.dom(".hidden-block").doesNotExist();
  });
});
```

#### Testing with Mock Outlet Args

```javascript
test("uses outlet args in conditions", async function (assert) {
  @block("outlet-args-block")
  class OutletArgsBlock extends Component {
    <template>
      <div class="outlet-args-block">
        Topic: {{@outletArgs.topic.title}}
      </div>
    </template>
  }

  withTestBlockRegistration(() => registerBlock(OutletArgsBlock));
  withPluginApi((api) =>
    api.renderBlocks("topic-outlet", [
      {
        block: OutletArgsBlock,
        conditions: { type: "outletArg", path: "topic.closed", value: false },
      },
    ])
  );

  // Mock outlet args with an open topic
  this.set("mockTopic", { id: 123, title: "Test Topic", closed: false });

  await render(
    <template>
      <BlockOutlet
        @name="topic-outlet"
        @outletArgs={{hash topic=this.mockTopic}}
      />
    </template>
  );

  assert.dom(".outlet-args-block").exists();
  assert.dom(".outlet-args-block").includesText("Test Topic");
});

test("hides when outlet arg condition fails", async function (assert) {
  @block("closed-topic-block")
  class ClosedTopicBlock extends Component {
    <template>
      <div class="closed-topic-block">Open topics only</div>
    </template>
  }

  withTestBlockRegistration(() => registerBlock(ClosedTopicBlock));
  withPluginApi((api) =>
    api.renderBlocks("closed-topic-outlet", [
      {
        block: ClosedTopicBlock,
        conditions: { type: "outletArg", path: "topic.closed", value: false },
      },
    ])
  );

  // Mock outlet args with a closed topic
  this.set("closedTopic", { id: 456, title: "Closed Topic", closed: true });

  await render(
    <template>
      <BlockOutlet
        @name="closed-topic-outlet"
        @outletArgs={{hash topic=this.closedTopic}}
      />
    </template>
  );

  assert.dom(".closed-topic-block").doesNotExist();
});
```

#### Key Testing Patterns

| Pattern | Import | Usage |
|---------|--------|-------|
| Register block | `registerBlock` from `discourse/tests/helpers/block-testing` | `withTestBlockRegistration(() => registerBlock(MyBlock))` |
| Register condition | `registerConditionType` from `discourse/tests/helpers/block-testing` | `withTestConditionRegistration(() => registerConditionType(MyCondition))` |
| Configure layout | `withPluginApi` from `discourse/lib/plugin-api` | `withPluginApi((api) => api.renderBlocks("outlet-name", [...]))` |
| Test condition validate | `validateConditions` from `discourse/tests/helpers/block-testing` | `validateConditions({ type: "my-type", ...args }, conditionTypes)` |
| Test condition evaluate | Direct instantiation with owner | `setOwner(condition, getOwner(this))` then `condition.evaluate(args, context)` |

> :exclamation: **Important:** The test helpers `withTestBlockRegistration` and `withTestConditionRegistration` take a **single callback parameter** (synchronous). They temporarily unfreeze the registries to allow registration during tests.

### Migration from Plugin Outlets

If you're adding a `<BlockOutlet>` to replace or complement a plugin outlet, here's the process.

#### Migration Checklist

1. **Identify the outlet area**
   - Is it a structured layout region?
   - Will multiple blocks potentially render here?

2. **Create a BlockOutlet**
   ```handlebars
   {{! Replace or add alongside existing plugin outlet }}
   <BlockOutlet @name="my-outlet" @outletArgs={{hash topic=this.topic}} />
   ```

3. **Convert connectors to blocks**
   ```javascript
   // Before: Plugin outlet connector
   // connectors/my-outlet/my-connector.js

   // After: Block component
   @block("my-plugin:my-block", { ... })
   export default class MyBlock extends Component { ... }
   ```

4. **Register blocks in pre-initializers**
   ```javascript
   // pre-initializers/register-blocks.js
   export default {
     before: "freeze-block-registry",

     initialize() {
       withPluginApi((api) => {
         api.registerBlock(MyBlock);
       });
     },
   };
   ```

5. **Configure layout in api-initializers**
   ```javascript
   // api-initializers/configure-blocks.js
   export default apiInitializer((api) => {
     api.renderBlocks("my-outlet", [
       { block: MyBlock, conditions: [...] },
     ]);
   });
   ```

6. **Test thoroughly**
   - Verify visibility in all scenarios
   - Check debug tools show expected output
   - Confirm no console errors

---

## 10. Terms to Know

Key terminology used throughout this documentation:

| Term | Definition |
|------|------------|
| **Block Schema** | The options passed to the `@block()` decorator that define a block's interface: its name, args schema, childArgs, constraints, and outlet restrictions. |
| **Block Entry** | An object in an outlet layout that specifies how to use a block: which block class, what args to pass, what conditions to evaluate, and any children. |
| **Outlet Layout** | An array of block entries passed to `renderBlocks()` that defines which blocks appear in an outlet and how they're configured. |
| **Container Block** | A block that can hold child blocks. Defined with `container: true` in the block schema. Responsible for rendering its children. |
| **Condition** | A declarative rule that determines whether a block should be visible. Evaluated at render time. |
| **Outlet** | A designated location in the UI where blocks can render. Defined by `<BlockOutlet @name="...">` in templates. |
| **Outlet Args** | Data passed from the template context to blocks via `@outletArgs` on the BlockOutlet component. |
| **Ghost Block** | A debug-mode placeholder that appears where a hidden block would render, showing why it's not visible. |
| **Factory Function** | A function that returns a Promise resolving to a block component, used for lazy loading. Registered with `registerBlock("name", () => import("./block"))`. |
| **Registry Freeze** | The point during boot when the block, outlet, and condition registries become immutable. Happens after the `freeze-block-registry` initializer runs. |
| **Namespace** | The prefix portion of a block name that identifies its source. Format: `plugin-name:` for plugins, `theme:theme-name:` for themes. |
| **Preprocessing Pipeline** | The internal process that transforms a layout configuration into renderable components, including block resolution, condition evaluation, and component creation. |
| **Evaluation Context** | The data available to conditions during evaluation, including outlet args and outlet name. |
