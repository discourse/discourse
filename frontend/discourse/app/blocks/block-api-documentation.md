# Block API Documentation

> **Note:** This documentation is a work in progress. We'll iterate on it together.

---

## 1. Philosophy and Mental Model

### The Problem Being Solved

Plugin outlets have served Discourse well for years, but they have limitations:

- **No conditional rendering.** You handle visibility logic inside your connector component, often duplicating checks across multiple connectors.
- **No coordination.** Multiple plugins extending the same outlet have no structured way to order themselves or share context.
- **Template-only extension.** Outlets are places to inject markup, but there's no registry of what's injected or metadata about it.
- **No validation.** Typos in outlet names fail silently. Invalid arguments aren't caught until runtime (if at all).

The Block API is a structured alternative for UI extension points that need:
- Declarative, validated conditions that determine when content appears
- A registry of what's been registered and where
- Coordinated rendering with predictable ordering
- Rich developer tooling for debugging visibility issues

The Block API is designed to handle the common cases—adding content to designated areas with conditional visibility, validation, and debugging tools. Plugin outlets remain available for complex scenarios requiring completely custom, bespoke components that don't fit the block model.

### Limitations

Before diving in, understand what the Block API *doesn't* do:

- **One layout per outlet.** If you call `renderBlocks("homepage-blocks", [...])` twice, the second call raises an error. There's no merging or appending—the first caller owns the outlet. This means two plugins targeting the same outlet will conflict, and the load order determines which one succeeds.

- **No runtime reconfiguration.** Block configurations are set at boot time during initializers. You can't add or remove blocks after the application starts. Conditions handle dynamic visibility, but the set of *possible* blocks is fixed.

- **All-or-nothing outlet ownership.** Unlike plugin outlets where multiple connectors coexist, a block outlet has a single owner that defines its entire layout. The intended pattern: plugins register blocks, themes call `renderBlocks()` to compose the layout. This separates content (plugins) from presentation (themes).

- **Conditions are synchronous.** The `evaluate()` method must return a boolean immediately. You can't await an API call to determine visibility. If you need async data, fetch it elsewhere and pass it via outlet args.

- **No partial re-evaluation.** When conditions depend on reactive state, the entire block tree re-evaluates. For outlets with many blocks or complex conditions, this can impact performance.

These constraints are intentional trade-offs for simplicity and predictability. For truly bespoke customizations that don't fit the block model—complex interactive components, entirely custom layouts, or cases requiring multiple independent contributors—plugin outlets remain available.

### The Core Abstraction: LEGO for UI

Think of the Block API like a LEGO system:

**Outlets are baseplates.** They're the foundation pieces with designated connection points where you can attach things. You can't stick LEGO pieces to the table—they need a baseplate. Similarly, blocks can only render in outlets, not arbitrary template locations. Each outlet (`homepage-blocks`, `sidebar-blocks`) is a baseplate positioned somewhere in the UI.

**Blocks are LEGO pieces.** They're self-contained components with standard connection points. Each piece has a part number (its name), a shape (its component), and specifications (its arg schema). You can't just invent pieces on the fly—they come from the set.

**The registry is your parts bin.** Before you start building, all available pieces are sorted into the bin. The registry knows every block that *could* be used. If you try to use a piece that isn't in the bin, you'll know immediately.

**Conditions are building instructions.** "Attach this piece only if the base is red" becomes "render only if user is admin." The builder (condition evaluator) checks the instructions at build time and decides whether to attach each piece.

**Container blocks are assemblies.** Some LEGO pieces are themselves assemblies—a pre-built car chassis that accepts wheels, or a house frame that accepts windows. Container blocks work the same way: they're blocks that hold other blocks.

This mental model helps explain the API's design decisions:

- **Why must blocks be registered before `renderBlocks()`?** You need all your pieces in the bin before you start building.
- **Why can't blocks render outside outlets?** LEGO pieces need baseplates—you can't attach them to thin air.
- **Why are conditions evaluated at render time?** Building instructions are followed when you're actually assembling, not when the pieces were manufactured.

### Complete Block Anatomy

Here's a complete block registration that uses every available option. We'll walk through each part:

```javascript
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/components/block-outlet";

@block("theme:my-theme:hero-banner", {
  // (A) Container mode - can this block contain child blocks?
  container: false,

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
  },

  // (D) Outlet restrictions - where can this block render?
  allowedOutlets: ["homepage-blocks", "hero-*"],

  // (E) Outlet exclusions - where should this block never render?
  deniedOutlets: ["sidebar-*"],
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

Let's examine each part:

#### (A) Block Name: `"theme:my-theme:hero-banner"`

The block name follows a strict namespacing convention:

| Format | Source | Example |
|--------|--------|---------|
| `block-name` | Core Discourse | `group`, `block-outlet` |
| `plugin:block-name` | Plugins | `chat:message-widget` |
| `theme:namespace:block-name` | Themes | `theme:tactile:hero-banner` |

**Why namespacing?** Prevents collisions. Two themes can both have a "banner" block without conflict because they're namespaced: `theme:tactile:banner` vs `theme:starter:banner`.

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
- They define their own wrapper markup (the system doesn't wrap them)
- They receive `classNames` directly in args to apply to their wrapper
- They inherit an implicit condition: "only render if I have visible children"

Non-container blocks, by contrast:
- Are automatically wrapped by the system with consistent layout markup
- Don't control their wrapper element
- Have `classNames` applied to the system-generated wrapper

**Default:** `false` (non-container)

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

**Supported types:**
- `"string"` - Text values
- `"number"` - Numeric values
- `"boolean"` - True/false
- `"array"` - Arrays (with optional `itemType` for validation)

**Schema properties:**
- `type` (required) - The argument type
- `required` (optional) - Whether the argument must be provided
- `default` (optional) - Default value if not provided
- `itemType` (optional, for arrays) - Type of items in the array
- `pattern` (optional, for strings) - Regex pattern for validation

#### (D) Allowed Outlets

```javascript
allowedOutlets: ["homepage-blocks", "hero-*"],
```

Restricts where this block can render. Uses [picomatch](https://github.com/micromatch/picomatch) glob syntax:
- `"homepage-blocks"` - Exact match
- `"hero-*"` - Wildcard (matches `hero-left`, `hero-right`, etc.)
- `"{sidebar,footer}-*"` - Brace expansion (matches `sidebar-*` OR `footer-*`)

**What happens if you omit it?** The block can render in any outlet.

**What if someone tries to use this block in `sidebar-blocks`?** They get a validation error: `Block "theme:my-theme:hero-banner" cannot be rendered in outlet "sidebar-blocks": denied by deniedOutlets pattern "sidebar-*".`

#### (E) Denied Outlets

```javascript
deniedOutlets: ["sidebar-*"],
```

Prevents the block from rendering in specific outlets. Same glob syntax as `allowedOutlets`.

**Conflict detection:** If a pattern appears in both `allowedOutlets` and `deniedOutlets`, you get an error at decoration time (when the class is defined), not at runtime.

### The Lifecycle: From Registration to Render

Understanding when things happen helps debug issues.

---

#### :rocket: Boot Time

**1. Pre-initializers run**
- `api.registerBlock(HeroBanner)`
  - Validates block name, namespace, decoration
  - Stores in `blockRegistry` Map
- `api.registerBlockOutlet("my-plugin:custom-outlet")`

**2. Registry freezes** (`freeze-block-registry` initializer)
- `registryFrozen = true`
- No more block registrations allowed

**3. API-initializers run**
- `api.renderBlocks("homepage-blocks", [...])`
  - Validates: outlet exists, blocks registered, schemas match
  - Validates: conditions syntax, arg names
  - Stores config in `blockConfigs` Map

---

#### :art: Render Time

**4. BlockOutlet renders** (`<BlockOutlet @name="homepage-blocks" />`)
- Retrieves config from `blockConfigs`
- Preprocesses: evaluates conditions, computes visibility

**5. Condition evaluation** (bottom-up for containers)
- For each block config:
  - If has conditions → evaluate via Blocks service
  - If container → recurse to children first
  - Set `__visible` = conditions passed && has visible children
- Result: each config now has `__visible` flag

**6. Component creation**
- Visible blocks → `curryComponent()` → wrapped with layout
- Hidden blocks (debug mode) → `GhostBlock` placeholder

**7. Template renders**
- `{{#each this.children as |child|}}` → `<child.Component />`

---

**Key insight:** Most validation happens at boot time, not render time. This means:
- Typos in condition types? Error at boot.
- Invalid arg names? Error at boot.
- Block not registered? Error at boot.
- Condition fails at runtime? Block silently doesn't render (or shows ghost in debug).

### Your First Block

Start with the absolute minimum—a block that just renders static content:

```javascript
// themes/my-theme/javascripts/discourse/blocks/welcome-banner.gjs
import Component from "@glimmer/component";
import { block } from "discourse/components/block-outlet";

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

That's it. Three files: the block, registration, and layout configuration.

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

**Config options reference:**

| Property | Required | Default | Notes |
|----------|----------|---------|-------|
| `block` | Yes | — | Component class or string name |
| `args` | No | `{}` | Passed to component as `@args` |
| `conditions` | No | — | If omitted, always renders |
| `classNames` | No | — | Added to wrapper element |
| `children` | No | — | Only for container blocks |

Now that you understand the concepts and have seen a complete example, let's look at the building blocks in more detail.

---

## 2. Core Architecture

### Using the Block API

What you need to know to build with blocks.

#### The `@block` Decorator

The decorator transforms a Glimmer component into a block. It adds:

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

#### The `<BlockOutlet>` Component

Place this in templates where blocks should render:

```handlebars
<BlockOutlet @name="homepage-blocks" />
```

**Named Blocks: `:before` and `:after`**

BlockOutlet supports Ember's named blocks pattern to render content around your blocks:

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

Both named blocks receive a boolean parameter indicating whether **any blocks are configured** for this outlet (i.e., whether `renderBlocks()` was called for it). This is configuration presence, not visibility—if all configured blocks have failing conditions, the boolean is still `true`.

**When to use each:**

| Named Block | Renders | Common Uses |
|-------------|---------|-------------|
| `:before` | Before all blocks | Section headers, introductory text, "featured" labels |
| `:after` | After all blocks | Empty states, fallback content, "see more" links |

**`:before` examples:**

```handlebars
{{! Add a header only when blocks exist }}
<BlockOutlet @name="sidebar-widgets">
  <:before as |hasWidgets|>
    {{#if hasWidgets}}
      <h3 class="sidebar-widgets__header">Widgets</h3>
    {{/if}}
  </:before>
</BlockOutlet>

{{! Always show a header, but style differently }}
<BlockOutlet @name="announcements">
  <:before as |hasAnnouncements|>
    <h2 class={{if hasAnnouncements "has-content"}}>Announcements</h2>
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
        <p>Your dashboard is empty. Install plugins to add widgets.</p>
      </div>
    {{/unless}}
  </:after>
</BlockOutlet>

{{! Show "view all" link when blocks exist }}
<BlockOutlet @name="recent-activity">
  <:after as |hasActivity|>
    {{#if hasActivity}}
      <a href="/activity" class="view-all">View all activity →</a>
    {{/if}}
  </:after>
</BlockOutlet>
```

**Combining both:**

```handlebars
<BlockOutlet @name="topic-sidebar">
  <:before as |hasSidebarContent|>
    {{#if hasSidebarContent}}
      <div class="sidebar-header">
        <h3>Related</h3>
      </div>
    {{/if}}
  </:before>

  <:after as |hasSidebarContent|>
    {{#if hasSidebarContent}}
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

**Outlet Args**

Pass data from the parent template to blocks via `@outletArgs`. Given a BlockOutlet like this:

```handlebars
{{! Example: a hypothetical outlet in a topic header template }}
<BlockOutlet
  @name="topic-header-blocks"
  @outletArgs={{hash topic=this.model user=this.currentUser}}
/>
```

> **Important difference from plugin outlets:** In blocks, outlet args are accessed via `@outletArgs`, not `@args`. The `@args` namespace is reserved for the block's configured args (from `renderBlocks()`). This separation is intentional—it clearly distinguishes "data from the template context" (`@outletArgs`) from "data from the block configuration" (`@args`).

```javascript
// In your block component:
<template>
  {{! Config args - from renderBlocks() config }}
  <h2>{{@title}}</h2>

  {{! Outlet args - from BlockOutlet's @outletArgs }}
  <p>Topic: {{@outletArgs.topic.title}}</p>
  <p>Author: {{@outletArgs.user.username}}</p>
</template>
```

Conditions can reference outlet args with the `outletArg` condition type or `source` parameters on other conditions.

#### The `renderBlocks()` Function

Configure which blocks render in an outlet:

```javascript
api.renderBlocks("homepage-blocks", [
  { block: Banner, args: { title: "Welcome" } },
  { block: Sidebar, conditions: { type: "user", loggedIn: true } },
]);
```

#### Optional Blocks

When referencing blocks by string name, you can append `?` to make the block **optional**:

```javascript
api.renderBlocks("dashboard", [
  { block: "analytics:stats-widget?" },  // Optional - won't error if missing
  { block: "chat:recent-messages?" },    // Optional
  { block: CoreBanner },                 // Required - will error if not registered
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

### Under the Hood

Now that you know how to use blocks, let's look at what's happening behind the scenes. This section is for those working on the Block API itself, or anyone curious about how the pieces fit together.

#### The Blocks Service

For runtime introspection, inject the service:

```javascript
@service blocks;

// Check if a block is registered
this.blocks.hasBlock("my-block")

// Get all registered blocks with metadata
this.blocks.listBlocksWithMetadata()
```

This is primarily useful for debugging, dev tools, and advanced scenarios where you need to query the registry programmatically.

The service is a thin wrapper around the block registry—let's look at what that registry actually does.

#### The Block Registry

The registry (`registration.js`) is a Map storing block name → block class (or factory). Internal tracking includes:

- **Resolved factory cache** - Stores resolved classes for lazy-loaded blocks
- **Pending resolutions** - Prevents duplicate concurrent async loads
- **Failed resolutions** - Prevents infinite retry loops
- **Source namespace map** - Enforces consistent namespacing per theme/plugin

The registry has two states:
- **Unfrozen** (during pre-initializers) - Registrations allowed
- **Frozen** (after `freeze-block-registry` initializer) - No more registrations

This two-phase design ensures all blocks are registered before any `renderBlocks()` calls.

With blocks registered, the next question is: how do we prevent someone from bypassing the system entirely?

#### The Security Symbol System

Blocks use private symbols to prevent unauthorized rendering:

```javascript
const __BLOCK_FLAG = Symbol("block");
const __BLOCK_CONTAINER_FLAG = Symbol("block-container");
```

These symbols:
1. Verify a component was decorated with `@block`
2. Authorize container blocks to render children
3. Prevent blocks from being used directly in templates (must go through `BlockOutlet`)

So we have blocks in a registry, protected by symbols. What happens when it's time to actually render them?

#### The Preprocessing Pipeline

When `<BlockOutlet>` renders:
1. Retrieves config from `blockConfigs` Map
2. Resolves block references (string names → classes, factories → resolved classes)
3. Evaluates conditions bottom-up (children before parents for container visibility)
4. Creates curried components for visible blocks
5. Creates ghost placeholders for hidden blocks (in debug mode)

That pipeline assumes everything is configured correctly. But what catches mistakes before they make it that far?

### The Contract: Schema Validation and Type Safety

The Block API provides multiple layers of validation:

**Config Key Validation:**
```javascript
// If you write:
{ block: MyBlock, conditon: [...] }  // typo: "conditon"

// You get:
// Error: Unknown config key: "conditon" (did you mean "conditions"?)
```

**Args Schema Validation:**
```javascript
@block("my-block", {
  args: {
    count: { type: "number", required: true },
  }
})

// If you write:
{ block: MyBlock, args: { count: "42" } }  // string, not number

// You get:
// Error: Arg "count" expects type "number", got "string"
```

**Condition Type Validation:**
```javascript
// If you write:
conditions: [{ type: "usr", admin: true }]  // typo: "usr"

// You get:
// Error: Unknown condition type: "usr" (did you mean "user"?)
```

**Reserved Args Protection:**
```javascript
// If you write:
{ block: MyBlock, args: { children: [...], _internal: true } }

// You get:
// Error: Reserved arg names: children, _internal. Names starting with
// underscore are reserved for internal use.
```

Validation catches configuration mistakes. But what about intentional misuse—someone trying to render blocks outside the system?

### The Security Model

Blocks use a secret symbol system to prevent unauthorized rendering:

```javascript
// Private symbols (not exported)
const __BLOCK_FLAG = Symbol("block");
const __BLOCK_CONTAINER_FLAG = Symbol("block-container");
```

These symbols are:
1. **Not exported** - External code can't access them
2. **Used for authorization** - Child blocks receive `$block$` arg with the container symbol
3. **Verified in constructor** - If the symbol doesn't match, throws an error

**Why this matters:**

```handlebars
{{! This will throw an error: }}
<MyBlock @title="Direct usage" />

{{! Blocks can ONLY be rendered through BlockOutlet: }}
<BlockOutlet @name="homepage-blocks" />
```

This prevents:
- Plugins bypassing condition evaluation
- Themes rendering blocks outside designated areas
- Security holes from arbitrary block placement

The only way a block can render is as a child of a container block that passes the `$block$` symbol in args. But wait—what authorizes the first block in the chain?

> **Trivia:** `<BlockOutlet>` is itself a block. Look at its definition and you'll see `@block("block-outlet", { container: true })`. It's a special container block that serves as the root of the block tree. It has a `__ROOT_BLOCK` static property set to the container symbol, which allows it to bypass the normal authorization check and start the chain of trust.

Finally, for those building dev tools or writing tests, there are some internal APIs worth knowing about.

### Private APIs and Extension Points

Some APIs are internal (prefixed with `_`) but available for specific use cases:

**Testing helpers:**
```javascript
import {
  resetBlockRegistryForTesting,
  withTestBlockRegistration,
  _setTestSourceIdentifier
} from "discourse/lib/blocks/registration";
```

**Debug hooks:**
```javascript
import {
  _setBlockDebugCallback,
  _setBlockLoggingCallback,
  // ... many more
} from "discourse/lib/blocks/debug-hooks";
```

These are used by dev tools and test infrastructure. They're not part of the public API and may change without notice.

---

## 3. The Evaluation Engine

We've covered registration, configuration, and the internal machinery. Now let's look at the heart of the system: how does a block decide whether to show itself?

### How Decisions Are Made

When a `<BlockOutlet>` renders, it needs to decide which blocks to show. This happens in the `#preprocessConfigs` method, which implements **bottom-up evaluation**.

**Why bottom-up?** Container blocks have an implicit condition: they only render if they have at least one visible child. We need to know child visibility before we can determine parent visibility.

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
for each block in configs:
  1. Resolve block reference (string name → class)
  2. Evaluate block's own conditions
  3. If container with children:
     a. Recursively preprocess children (this computes their visibility)
     b. Check if any child is visible
  4. Set __visible = conditions passed AND (not container OR has visible children)
  5. If not visible, set __failureReason for debug display
```

That handles basic conditions. But what if you need more complex logic?

### Condition Combinators: AND, OR, NOT

Conditions support three combinators for complex logic:

**AND (array of conditions):**
```javascript
conditions: [
  { type: "user", loggedIn: true },
  { type: "user", minTrustLevel: 2 },
  { type: "route", urls: ["$DISCOVERY_PAGES"] }
]
// All three must pass
```

**OR (`any` wrapper):**
```javascript
conditions: [
  {
    any: [
      { type: "user", admin: true },
      { type: "user", moderator: true }
    ]
  }
]
// At least one must pass
```

**NOT (`not` wrapper):**
```javascript
conditions: [
  {
    not: { type: "route", urls: ["/admin/**"] }
  }
]
// Must NOT be on admin pages
```

**Nested combinators:**
```javascript
conditions: [
  { type: "user", loggedIn: true },
  {
    any: [
      { type: "user", admin: true },
      {
        not: { type: "route", urls: ["/admin/**"] }
      }
    ]
  }
]
// Logged in AND (admin OR not on admin pages)
```

With combinators you can express almost any visibility rule. But where do conditions get their data?

### Context Awareness: What Conditions Can Access

Conditions receive a context object with access to:

**Outlet Args:**
```javascript
// Passed from BlockOutlet
<BlockOutlet @name="topic-blocks" @outletArgs={{hash topic=this.topic}} />

// Accessible in conditions via source or outletArg condition
{ type: "outletArg", path: "topic.closed", value: true }
{ type: "user", source: "@outletArgs.topicAuthor", admin: true }
```

**Services (via injection):**
```javascript
// Inside a condition class
@service router;
@service currentUser;
@service siteSettings;
@service capabilities;
```

**Debug context:**
```javascript
// When debug logging is enabled
context.debug = true;
context._depth = 2;  // Nesting level for log indentation
context.logger = { ... }; // Interface for structured logging
```

That covers how conditions work. But what happens when you make a mistake configuring them?

---

## 4. Developer Experience & Error Handling

A powerful API is only useful if you can debug it when things go wrong. The Block API invests heavily in developer experience—not just catching errors, but explaining them in a way that points you toward the solution.

### Helpful Error Messages

The Block API is designed to guide you toward the fix, not just tell you something is wrong.

**Unknown keys with suggestions:**
```javascript
// What you wrote:
{ block: MyBlock, conditon: [{ type: "user" }] }

// Error message:
[Blocks] Invalid block config at blocks[0] for outlet "homepage-blocks":
Unknown config key: "conditon" (did you mean "conditions"?).
Valid keys are: block, args, children, conditions, name, classNames.

Location: blocks[0].conditon

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

### Validation Feedback

Validation happens at registration time when possible, giving you immediate feedback rather than runtime surprises.

**Source-mapped stack traces:**

When an error occurs, the stack trace points to your code, not internal block machinery:

```javascript
// Error shows:
at renderBlocks (your-theme/api-initializers/configure-blocks.js:15:3)
// Not:
at validateConfig (discourse/lib/blocks/config-validation.js:400:1)
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

### Progressive Disclosure

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

Start simple, add complexity only when you need it. You don't have to master conditions to render a block, and you don't have to master combinators to use a single condition.

So far we've focused on what happens when things go wrong. But what about when things *seem* fine but aren't working as expected?

---

## 5. Developer Tools & Diagnostics

Error messages help when something is wrong. But sometimes you need to understand what's happening when everything appears to work—just not the way you expected. That's where the debugging tools come in.

### Complete Tools Overview

The Block API includes comprehensive debugging tools accessible via the dev tools toolbar:

| Tool | What it does | How to enable |
|------|--------------|---------------|
| **Console Logging** | Logs condition evaluations to browser console | Toggle "Block Debug" in toolbar |
| **Visual Overlay** | Shows block boundaries with badges and tooltips | Toggle "Block Overlay" in toolbar |
| **Outlet Boundaries** | Shows outlet boundaries even when empty | Toggle "Outlet Boundaries" in toolbar |
| **Ghost Blocks** | Shows hidden blocks as dashed placeholders | Enabled with Visual Overlay |

### Console Logging

When enabled, every block render is logged with its condition tree:

```
[Blocks] ✓ RENDERED hero-banner in homepage-blocks
  ├─ ✓ AND (2 conditions)
  │  ├─ ✓ user { loggedIn: true }
  │  └─ ✓ route { urls: ["$DISCOVERY_PAGES"] }

[Blocks] ✗ SKIPPED admin-banner in homepage-blocks
  ├─ ✗ AND (2 conditions)
  │  ├─ ✗ user { admin: true }
  │  └─ ─ route { urls: ["$DISCOVERY_PAGES"] }  // not evaluated (short-circuit disabled in debug)
```

**What the icons mean:**
- `✓` (green) - Condition passed
- `✗` (red) - Condition failed

**Type mismatch warnings:**
```
[Blocks] ✗ SKIPPED my-block in homepage-blocks
  ├─ ✗ route
  │  └─ ✗ queryParams: filter ⚠ type mismatch: actual is undefined, condition specifies string
  │     { actual: undefined, configured: "solved" }
```

### Visual Overlay

When enabled, each rendered block shows:

1. **Badge** - Block name with cube icon
2. **Tooltip** (on hover/click) containing:
   - Block name and location (outlet path)
   - Conditions that were evaluated (if any)
   - Arguments passed to the block
   - Outlet args available

**Example tooltip content:**

> :ice_cube: **hero-banner** in `homepage-blocks`
>
> **Conditions** (passed)
> - AND
>   - user (loggedIn: true)
>   - route (urls: ["$DISCOVERY_PAGES"])
>
> **Arguments**
> - title: "Welcome"
> - ctaText: "Get Started"
>
> **Outlet Args**
> - topic: Topic { id: 123, ... }

### Ghost Blocks

When a block's conditions fail, a ghost placeholder appears showing:

1. **Dashed outline** - Where the block would render
2. **Badge** - Block name with "(hidden)" label
3. **Tooltip** explaining why:
   - "This block is not rendered because its conditions failed."
   - "This container block is not rendered because none of its children are visible."
   - "This optional block is not rendered because it's not registered."

**Ghost children:**

For container blocks hidden due to no visible children, the ghost shows nested ghost children:

> :ice_cube: **group** (hidden)
> > :ice_cube: **banner-a** (hidden)
>
> > :ice_cube: **banner-b** (hidden)

Tools are great, but knowing *when* to use *which* tool is the real skill. Here are some common scenarios.

### Debugging Workflows

**"I can't see my block"**

1. Enable **Console Logging** in dev tools
2. Navigate to the page where the block should appear
3. Look for your block in the console:
   - `✗ SKIPPED` - Check which condition failed
   - Not logged at all - Block not registered or outlet not configured

4. Enable **Visual Overlay** and **Outlet Boundaries**
5. Find the outlet where your block should render
6. Check if a ghost appears (conditions failed) or nothing (configuration issue)

**"My condition isn't working"**

1. Enable **Console Logging**
2. Expand the log for your block
3. Check the condition tree:
   - Is the condition type correct?
   - Are the arguments what you expect?
   - Is there a type mismatch warning?

4. For route conditions, check:
   - Is the current URL what you expect?
   - Are shortcuts matching? (`$CATEGORY_PAGES` vs actual category page)
   - Are query params present?

**"I'm not sure what's happening"**

1. Enable all debug tools
2. Open browser DevTools console
3. Navigate through the app and watch:
   - Which blocks render/skip on each page
   - What conditions are evaluated
   - What the actual vs expected values are

4. Click on block badges to see:
   - What arguments were passed
   - What outlet args are available
   - The full condition specification

### State Persistence

Debug tool settings are saved to sessionStorage:
- Survives page refreshes
- Resets on browser restart
- Per-tab independent state

This means you can enable debugging, navigate around, and the tools stay enabled.

You've got the tools to see what's happening. Now you need to know what all those condition types actually do.

---

## 6. Conditions & Logic

We've mentioned conditions throughout this document. Now let's cover each one in detail—what it checks, what options it accepts, and when to use it.

### Available Conditions

#### Route Condition

Evaluates based on the current URL path, semantic shortcuts, and parameters.

```javascript
{ type: "route", urls: [...], excludeUrls: [...], params: {...}, queryParams: {...} }
```

> **Why URLs instead of Ember route names?** Using internal route names like `discovery.latest` would make them part of the public API—any rename would break plugins and themes. URLs are already effectively public: changing them breaks bookmarks, external links, and SEO. By matching URLs, we avoid coupling blocks to Discourse's internal routing structure.

**URL Patterns (picomatch glob syntax):**
- `"/latest"` - Exact path match
- `"/c/*"` - Single segment wildcard (`/c/foo` but not `/c/foo/bar`)
- `"/c/**"` - Multi-segment wildcard (`/c/foo`, `/c/foo/bar`, `/c/foo/bar/baz`)
- `"/t/*/**"` - Combined (`/t/123/slug`, `/t/123/slug/4`)
- `"{/latest,/top}"` - Brace expansion (matches either)

**Shortcuts (semantic page types):**
- `$CATEGORY_PAGES` - Any category page
- `$DISCOVERY_PAGES` - Discovery routes (latest, top, new) excluding custom homepage
- `$HOMEPAGE` - Custom homepage only
- `$TAG_PAGES` - Any tag page
- `$TOP_MENU` - Discovery routes in top navigation

**URL vs Shortcut:**

Shortcuts are preferred when you want to match page types regardless of URL structure. URLs are preferred when you need specific path patterns.

```javascript
// Shortcut: matches category pages regardless of URL structure
{ type: "route", urls: ["$CATEGORY_PAGES"] }

// URL pattern: matches specific path structure
{ type: "route", urls: ["/c/**"] }

// The URL pattern might miss category pages with custom routes
// The shortcut checks the actual page context
```

**Parameters:**
```javascript
// Match specific route params
{
  type: "route",
  urls: ["/t/**"],
  params: { slug: "welcome" }
}

// Match query params
{
  type: "route",
  urls: ["$DISCOVERY_PAGES"],
  queryParams: { filter: "solved" }
}

// OR logic for params
{
  type: "route",
  urls: ["$DISCOVERY_PAGES"],
  queryParams: {
    any: [{ filter: "solved" }, { filter: "open" }]
  }
}
```

#### User Condition

Evaluates based on user state. By default, checks the **current user** (the person viewing the page). Use `source` to check a different user from outlet args.

```javascript
{ type: "user", loggedIn: true, admin: true, moderator: true, staff: true,
  minTrustLevel: 0, maxTrustLevel: 4, groups: ["beta-testers"] }
```

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

**Multiple conditions use AND logic:**
```javascript
// User must be logged in AND trust level 2+ AND in beta-testers group
{ type: "user", loggedIn: true, minTrustLevel: 2, groups: ["beta-testers"] }
```

**Check outlet arg user:**
```javascript
// Check the topic author instead of current user
{ type: "user", source: "@outletArgs.topicAuthor", admin: true }
```

#### Setting Condition

Evaluates based on site settings or custom settings objects.

```javascript
{ type: "setting", name: "setting_name", enabled: true, equals: "value",
  includes: [...], contains: "value", containsAny: [...], source: {...} }
```

| Property | Type | Description |
|----------|------|-------------|
| `name` | `string` | Setting key (required) |
| `enabled` | `boolean` | true = setting truthy, false = setting falsy |
| `equals` | `any` | Exact value match |
| `includes` | `array` | Setting value is in this array (for enum settings) |
| `contains` | `string` | List setting contains this value |
| `containsAny` | `array` | List setting contains any of these values |
| `source` | `object` | Custom settings object (e.g., theme settings) |

**Only one condition type per setting:**
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

#### Viewport Condition

Evaluates based on viewport size and device capabilities.

```javascript
{ type: "viewport", min: "lg", max: "xl", mobile: true, touch: true }
```

**Breakpoints:**
- `sm` - ≥640px
- `md` - ≥768px
- `lg` - ≥1024px
- `xl` - ≥1280px
- `2xl` - ≥1536px

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

> **Note:** For simple show/hide based on viewport, CSS media queries are often more performant. Use this condition when you need to completely remove components from the DOM.

#### OutletArg Condition

Evaluates based on outlet arg values.

```javascript
{ type: "outletArg", path: "topic.closed", value: true }
```

| Property | Type | Description |
|----------|------|-------------|
| `path` | `string` | Dot-notation path to property (required) |
| `value` | `any` | Value to match (see matching rules) |
| `exists` | `boolean` | true = property exists, false = property undefined |

> :warning: You cannot use both `value` and `exists` together—they are mutually exclusive. Use `value` to check what something equals, use `exists` to check whether it's defined at all.

**Value matching rules:**
- `undefined` → passes if target is truthy
- `[a, b, c]` → passes if target matches ANY element (OR logic)
- `{ not: x }` → passes if target does NOT match x
- Other → passes if target === value

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

### Combining Conditions

**AND logic (array):**
```javascript
conditions: [
  { type: "user", loggedIn: true },
  { type: "route", urls: ["$DISCOVERY_PAGES"] }
]
```

**OR logic (any wrapper):**
```javascript
conditions: [
  {
    any: [
      { type: "user", admin: true },
      { type: "user", moderator: true }
    ]
  }
]
```

**NOT logic (not wrapper):**
```javascript
conditions: [
  { not: { type: "route", urls: ["/admin/**"] } }
]
```

**Complex combinations:**
```javascript
// Show for: logged in users who are either admins OR (TL2+ and not on admin pages)
conditions: [
  { type: "user", loggedIn: true },
  {
    any: [
      { type: "user", admin: true },
      [
        { type: "user", minTrustLevel: 2 },
        { not: { type: "route", urls: ["/admin/**"] } }
      ]
    ]
  }
]
```

The built-in conditions cover most cases. But if you need something specific to your domain, you can create your own.

### Custom Conditions

You can create custom condition types:

```javascript
import { BlockCondition, raiseBlockValidationError } from "discourse/blocks/conditions";
import { blockCondition } from "discourse/blocks/conditions/decorator";
import { service } from "@ember/service";

@blockCondition({
  type: "feature-flag",
  validArgKeys: ["flag", "enabled"],
})
export default class FeatureFlagCondition extends BlockCondition {
  @service featureFlags;

  validate(args) {
    super.validate(args);

    if (!args.flag) {
      raiseBlockValidationError(
        "FeatureFlagCondition: `flag` argument is required."
      );
    }
  }

  evaluate(args) {
    const { flag, enabled = true } = args;
    const isEnabled = this.featureFlags.isEnabled(flag);
    return enabled ? isEnabled : !isEnabled;
  }
}

// Register in an initializer
api.registerBlockConditionType(FeatureFlagCondition);

// Use in block configs
{
  block: MyBlock,
  conditions: [{ type: "feature-flag", flag: "new_feature", enabled: true }]
}
```

You've seen the individual pieces. Time to watch them work together.

---

## 7. Practical Patterns

Enough theory—let's build some blocks. These tutorials progress from simple to complex, showing how the concepts fit together in practice.

### Tutorial 1: A Simple Promotional Banner

Let's build a banner that shows on the homepage for non-admin users.

**Step 1: Create the block component**

```javascript
// themes/my-theme/javascripts/discourse/blocks/promo-banner.gjs
import Component from "@glimmer/component";
import { block } from "discourse/components/block-outlet";

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

> :bulb: Use BEM naming convention for CSS classes: `.block-name`, `.block-name__element`, `.block-name--modifier`. This keeps styles scoped and predictable.

**Step 2: Register the block**

```javascript
// themes/my-theme/javascripts/discourse/pre-initializers/register-blocks.js
import { withPluginApi } from "discourse/lib/plugin-api";
import PromoBanner from "../blocks/promo-banner";

export default {
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
        { type: "route", urls: ["$HOMEPAGE"] },
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

That covered the basics. Now let's use outlet args to make blocks respond to their context.

### Tutorial 2: Context-Aware Topic Badges

Let's build a badge system that shows different badges based on topic state. This example assumes a hypothetical `topic-header-blocks` outlet that provides `topic` in its outlet args.

**Step 1: Create reusable badge block**

```javascript
// plugins/my-plugin/assets/javascripts/discourse/blocks/topic-badge.gjs
import Component from "@glimmer/component";
import { block } from "discourse/components/block-outlet";
import icon from "discourse/helpers/d-icon";

@block("my-plugin:topic-badge", {
  description: "A badge displayed on topics based on conditions",
  args: {
    label: { type: "string", required: true },
    icon: { type: "string" },
    variant: { type: "string", default: "default" },  // default, success, warning, danger
  },
  allowedOutlets: ["topic-*", "post-*"],
})
export default class TopicBadge extends Component {
  <template>
    <span class="topic-badge topic-badge--{{@variant}}">
      {{#if @icon}}
        {{icon @icon}}
      {{/if}}
      <span class="topic-badge__label">{{@label}}</span>
    </span>
  </template>
}
```

**Step 2: Configure multiple badge instances**

```javascript
// plugins/my-plugin/assets/javascripts/discourse/api-initializers/topic-badges.js
import { apiInitializer } from "discourse/lib/api";
import TopicBadge from "../blocks/topic-badge";

export default apiInitializer((api) => {
  api.renderBlocks("topic-header-blocks", [
    // Closed topic badge
    {
      block: TopicBadge,
      args: { label: "Closed", icon: "lock", variant: "danger" },
      conditions: [
        { type: "outletArg", path: "topic.closed", value: true },
      ],
    },

    // Pinned topic badge
    {
      block: TopicBadge,
      args: { label: "Pinned", icon: "thumbtack", variant: "warning" },
      conditions: [
        { type: "outletArg", path: "topic.pinned", value: true },
      ],
    },

    // Solved topic badge (for staff only)
    {
      block: TopicBadge,
      args: { label: "Solved", icon: "check", variant: "success" },
      conditions: [
        { type: "outletArg", path: "topic.accepted_answer", exists: true },
        { type: "user", staff: true },
      ],
    },

    // High engagement badge
    {
      block: TopicBadge,
      args: { label: "Hot", icon: "fire", variant: "warning" },
      conditions: [
        { type: "outletArg", path: "topic.like_count", value: { gte: 50 } },
      ],
    },
  ]);
});
```

**What we accomplished:**
- Same block component, different configurations
- Each badge has its own conditions
- Conditions use outlet args to access topic data
- Staff-only visibility for certain badges

So far we've been working within a single theme or plugin. The real power of the Block API emerges when multiple plugins provide blocks and a theme composes them into a unified layout.

### Tutorial 3: Theme Dashboard from Plugin Blocks

Let's build a community dashboard where:
- **Plugins** register blocks (provide functionality)
- **Theme** calls `renderBlocks()` to compose the layout

This separation is intentional: plugins provide content, themes control presentation. Given a hypothetical `community-dashboard` outlet in core, here's how the pieces fit together.

**Plugin A: Analytics Plugin**

First, the analytics plugin creates and registers a stats widget block:

```javascript
// plugins/discourse-analytics/assets/javascripts/discourse/blocks/stats-widget.gjs
import Component from "@glimmer/component";
import { block } from "discourse/components/block-outlet";

@block("discourse-analytics:stats-widget", {
  description: "Displays community statistics",
  args: {
    title: { type: "string", default: "Community Stats" },
    showGrowth: { type: "boolean", default: true },
  },
})
export default class StatsWidget extends Component {
  <template>
    <div class="stats-widget">
      <h3 class="stats-widget__title">{{@title}}</h3>
      <ul class="stats-widget__list">
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
import StatsWidget from "../blocks/stats-widget";

export default {
  initialize() {
    withPluginApi((api) => {
      api.registerBlock(StatsWidget);
    });
  },
};
```

**Plugin B: Tasks Plugin**

The tasks plugin provides a task list block:

```javascript
// plugins/discourse-tasks/assets/javascripts/discourse/blocks/task-list.gjs
import Component from "@glimmer/component";
import { block } from "discourse/components/block-outlet";

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
import { block } from "discourse/components/block-outlet";

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
      block: "discourse-analytics:stats-widget?",
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
      conditions: { type: "viewport", minWidth: 768 },
    },
  ]);
});
```

> :exclamation: Notice the `?` suffix on each block name (e.g., `"discourse-analytics:stats-widget?"`). This marks the block as **optional**. If the plugin isn't installed or is disabled, the block silently skips instead of throwing an error. This is essential when themes reference blocks from plugins that may or may not be present.

**What we accomplished:**
- Three plugins each provide focused, reusable blocks
- Theme controls layout and configuration without touching plugin code
- Optional blocks (`?` suffix) gracefully handle missing plugins
- Conditions are set by the theme based on its design requirements
- Plugins don't need to know about each other
- Adding a new plugin's block to the dashboard is just one more entry in `renderBlocks()`

That's the Block API in practice. What follows is the complete reference for when you need to look something up.

---

## 8. Reference

When you know what you're looking for, start here.

### API Surface

#### Plugin API Methods

```javascript
api.registerBlock(BlockClass)
api.registerBlock("name", () => import("./block"))
api.renderBlocks(outletName, blockConfigs)
api.registerBlockOutlet(outletName, options)
api.registerBlockConditionType(ConditionClass)
```

#### Block Decorator

```javascript
@block(name, options)

// Options:
{
  container: boolean,           // Can contain child blocks
  description: string,          // Human-readable description
  args: { [key]: ArgSchema },   // Argument definitions
  allowedOutlets: string[],     // Glob patterns for allowed outlets
  deniedOutlets: string[],      // Glob patterns for denied outlets
}

// ArgSchema:
{
  type: "string" | "number" | "boolean" | "array",
  required?: boolean,
  default?: any,
  itemType?: "string" | "number" | "boolean",  // For arrays
  pattern?: RegExp,                             // For strings
}
```

#### Block Configuration

```javascript
{
  block: BlockClass | "block-name" | "block-name?",  // Required
  args?: { [key]: any },
  conditions?: ConditionSpec | ConditionSpec[],
  classNames?: string | string[],
  children?: BlockConfig[],      // Only for container blocks
}
```

#### Condition Specification

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

### Configuration Options

#### Route Condition Args

| Arg | Type | Description |
|-----|------|-------------|
| `urls` | `string[]` | URL patterns or shortcuts to match |
| `excludeUrls` | `string[]` | URL patterns or shortcuts to exclude |
| `params` | `object` | Route params to match |
| `queryParams` | `object` | Query params to match |

#### User Condition Args

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

#### Setting Condition Args

| Arg | Type | Description |
|-----|------|-------------|
| `name` | `string` | Setting key (required) |
| `source` | `object` | Custom settings object |
| `enabled` | `boolean` | Setting is truthy/falsy |
| `equals` | `any` | Exact value match |
| `includes` | `array` | Value is in array |
| `contains` | `string` | List contains value |
| `containsAny` | `array` | List contains any value |

#### Viewport Condition Args

| Arg | Type | Description |
|-----|------|-------------|
| `min` | `string` | Minimum breakpoint |
| `max` | `string` | Maximum breakpoint |
| `mobile` | `boolean` | Mobile device only |
| `touch` | `boolean` | Touch device only |

#### OutletArg Condition Args

| Arg | Type | Description |
|-----|------|-------------|
| `path` | `string` | Dot-notation path (required) |
| `value` | `any` | Value to match |
| `exists` | `boolean` | Property existence check |

### Troubleshooting Guide

#### Block not appearing

1. **Is the block registered?**
   - Check for errors in console during boot
   - Verify pre-initializer runs before `freeze-block-registry`

2. **Is the outlet configured?**
   - Check that `renderBlocks()` was called with correct outlet name
   - Enable outlet boundaries to see if outlet exists

3. **Are conditions failing?**
   - Enable console logging
   - Check for `✗ SKIPPED` in console
   - Review which condition failed

4. **Is the outlet rendered?**
   - Check that `<BlockOutlet @name="...">` exists in template
   - Verify outlet name matches exactly

#### Validation errors

1. **"Unknown config key"**
   - Check for typos in config object
   - Valid keys: block, args, conditions, classNames, children

2. **"Unknown condition type"**
   - Check condition type spelling
   - Ensure custom conditions are registered

3. **"Block not registered"**
   - Move registration to pre-initializer
   - Ensure pre-initializer runs before `freeze-block-registry`

4. **"Cannot render in outlet"**
   - Check block's `allowedOutlets` and `deniedOutlets`
   - Verify outlet name against patterns

#### Conditions not evaluating as expected

1. **Type mismatches**
   - Check console for type mismatch warnings
   - Ensure query params are compared as strings if that's their type

2. **Shortcut not matching**
   - Verify you're on the expected page type
   - Check discovery service state (category, tag, custom)

3. **Outlet args undefined**
   - Verify outlet passes args: `@outletArgs={{hash topic=this.topic}}`
   - Check path spelling in condition

---

*This documentation is generated from source code analysis and may be updated as the API evolves.*
