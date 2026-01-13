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

### What Blocks Are For

Blocks are designed for **structured layout areas**—regions where you want to compose multiple panels, cards, or content sections with validation, conditions, and theme control:

- Homepage content grids
- Sidebar panel areas
- Dashboard panels
- Category page customizations
- Discovery page sections

**Blocks are NOT intended for:**

- Small UI additions (badges, icons, buttons)
- Avatar modifications
- Minor UI tweaks throughout the app
- Places where the "composed layout" model doesn't fit

For smaller customizations, plugin outlets remain the right choice. Blocks and plugin outlets are complementary—a page might use blocks for its main content layout while using plugin outlets for small additions elsewhere.

### Limitations

Before diving in, understand what the Block API *doesn't* do:

- **One layout per outlet.** If you call `renderBlocks("homepage-blocks", [...])` twice, the second call raises an error. There's no merging or appending—the first caller owns the outlet. This means two plugins targeting the same outlet will conflict, and the load order determines which one succeeds.

- **No runtime reconfiguration.** Outlet layouts are set at boot time during initializers. You can't add or remove blocks after the application starts. Conditions handle dynamic visibility, but the set of *possible* blocks is fixed.

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

### Beyond LEGO: The Publication Model

The LEGO metaphor helps with structure but doesn't explain ownership, conditions, or coordination. For these, think of the Block API like a **publication system**:

| Publication | Block API |
|-------------|-----------|
| Sections (Front Page, Features, Sidebar) | Outlets |
| Content pieces (articles, ads, panels) | Blocks |
| Content providers (wire services, columnists) | Plugins registering blocks |
| In-house writers | Theme components registering blocks |
| Editor-in-chief | Theme calling `renderBlocks()` |
| Publishing rules ("subscribers only") | Conditions |
| Content library | Block registry |

**Why this model works:**

**Editorial Control:** Just like a publication has one editor deciding layout, each outlet has a single owner (the theme) that composes the layout. Plugins submit content to the library, but the editor decides what gets published where.

**Conditional Publishing:** "Only show this to logged-in users" is like "subscribers only." "Only on category pages" is like "only in the Sports section." Conditions are publishing rules.

**Content Providers:** Plugins are like wire services (AP, Reuters)—they provide content but don't control placement. Theme components are like in-house writers—also providing content, but part of the publication's own team.

**The Editor Composes:** The theme is the editor-in-chief. It looks at available content (registered blocks) and decides: "Put the analytics panel here, the tasks panel there, skip the gamification panel entirely." This is `renderBlocks()`.

This model explains why:
- Multiple plugins can provide blocks without conflict (content providers don't fight)
- Only one caller can configure an outlet (one editor per section)
- Conditions are declarative (publishing rules are set, not coded inline)
- Blocks appear/disappear based on state (just like time-sensitive content)

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

Let's examine each part:

#### (A) Block Name: `"theme:my-theme:hero-banner"`

The block name follows a strict namespacing convention:

| Format | Source | Example |
|--------|--------|---------|
| `block-name` | Core Discourse | `group`, `block-outlet` |
| `plugin:block-name` | Plugins | `chat:message-panel` |
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

**Type-specific properties:**

| Property | Types | Description |
|----------|-------|-------------|
| `itemType` | `array` | Type of items (`"string"`, `"number"`, `"boolean"`) |
| `pattern` | `string` | Regex pattern for validation |
| `minLength` | `string`, `array` | Minimum length (characters or items) |
| `maxLength` | `string`, `array` | Maximum length (characters or items) |
| `min` | `number` | Minimum value (inclusive) |
| `max` | `number` | Maximum value (inclusive) |
| `integer` | `number` | Must be a whole number |
| `enum` | `string`, `number` | Restrict to specific values |

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
}
```

> :bulb: **Tip:** Use `required` OR `default`, not both—an arg with a default is never missing.

#### (D) Constraints

```javascript
constraints: {
  atLeastOne: ["categoryId", "tagName"],
}
```

Constraints define validation rules across multiple arguments. They're checked at runtime after defaults are applied, and errors are caught at boot time when `renderBlocks()` is called.

**Constraint types:**

| Constraint | Meaning | Example |
|------------|---------|---------|
| `atLeastOne` | At least one arg must be provided | `atLeastOne: ["id", "tag"]` |
| `exactlyOne` | Exactly one arg must be provided (mutual exclusion + required) | `exactlyOne: ["id", "tag"]` |
| `allOrNone` | Either all are provided or none | `allOrNone: ["width", "height"]` |

**Error messages:**

```
Block "featured-list": at least one of "id", "tag" must be provided.
Block "featured-list": exactly one of "id", "tag" must be provided, but got both.
Block "featured-list": exactly one of "id", "tag" must be provided, but got none.
Block "featured-list": args "width", "height" must be provided together or not at all.
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

Restricts where this block can render. Uses [picomatch](https://github.com/micromatch/picomatch) glob syntax:
- `"homepage-blocks"` - Exact match
- `"hero-*"` - Wildcard (matches `hero-left`, `hero-right`, etc.)
- `"{sidebar,footer}-*"` - Brace expansion (matches `sidebar-*` OR `footer-*`)

**What happens if you omit it?** The block can render in any outlet.

**What if someone tries to use this block in `sidebar-blocks`?** They get a validation error: `Block "theme:my-theme:hero-banner" cannot be rendered in outlet "sidebar-blocks": denied by deniedOutlets pattern "sidebar-*".`

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
  - Stores layout in `outletLayouts` Map

---

#### :art: Render Time

**4. BlockOutlet renders** (`<BlockOutlet @name="homepage-blocks" />`)
- Retrieves layout from `outletLayouts`
- Preprocesses: evaluates conditions, computes visibility

**5. Condition evaluation** (bottom-up for containers)
- For each block entry:
  - If has conditions → evaluate via Blocks service
  - If container → recurse to children first
  - Set `__visible` = conditions passed && has visible children
- Result: each entry now has `__visible` flag

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

**Entry options reference:**

| Property | Required | Default | Notes |
|----------|----------|---------|-------|
| `block` | Yes | — | Component class or string name |
| `args` | No | `{}` | Passed to component as `@args` |
| `conditions` | No | — | If omitted, always renders |
| `classNames` | No | — | Added to wrapper element |
| `children` | No | — | Only for container blocks |
| `containerArgs` | No | — | Metadata for parent container (when used as child) |

Now that you understand the concepts and have seen a complete example, let's look at the building blocks in more detail.

---

## 2. Core Architecture

### Blocks and Plugin Outlets

Blocks and plugin outlets serve different purposes:

| Aspect | Blocks | Plugin Outlets |
|--------|--------|----------------|
| **Intended for** | Structured layout areas (panel grids, panels) | Injections and small additions |
| **Model** | Composed layout (theme orchestrates) | Content injection or wrapping |
| **Conditions** | Declarative, validated at boot | Custom logic in your component |
| **Dev tools** | Ghost blocks, condition logging, outlet boundaries, visual overlays | Outlet decorators, Ember inspector |
| **Typical use** | Homepage sections, sidebars, dashboards | Badges, buttons, small UI tweaks |

**They're complementary, not competing.** A category page might use:
- Blocks for its main content area (grid of panels)
- Plugin outlets for small additions (extra buttons, badges)

**Use blocks when:**
- You have a region that should display composed content (panels, cards, sections)
- You want themes to control what appears and in what order
- You need boot-time validation and condition debugging

**Use plugin outlets when:**
- You're making small additions to existing UI
- You're wrapping or modifying existing content
- The "composed layout" model doesn't fit your use case

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
<BlockOutlet @name="sidebar-panels">
  <:before as |hasPanels|>
    {{#if hasPanels}}
      <h3 class="sidebar-panels__header">Panels</h3>
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
        <p>Your dashboard is empty. Install plugins to add panels.</p>
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

#### Plugins, Theme Components, and Themes

The Block API separates **providing blocks** from **composing layouts**:

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
- The theme (editor) decides what appears where
- Optional blocks (`?`) handle missing plugins gracefully

**Can plugins or theme components call `renderBlocks()`?**

Yes. When a plugin or theme component calls `renderBlocks()`, it **claims ownership** of that outlet. This works, but adds constraints to the Discourse instance:

- No other extension can configure that outlet (they'll get an error)
- The theme must be written knowing this constraint exists
- You can't simply add a theme component that renders blocks to any arbitrary theme
- All compatible extensions must be coordinated to prevent conflicts

**When this makes sense:**

- **Self-contained plugins** that own specific outlets no one else needs
- **Heavily customized instances** where a plugin also manages the layout/theme
- **Turnkey solutions** where the plugin provides a complete experience

**When to avoid:**

- Reusable theme components meant to work across different themes
- Plugins that should compose nicely with other extensions
- Outlets that multiple contributors might want to customize

The recommended pattern for maximum flexibility is: **plugins and theme components register blocks; themes compose layouts.** But for controlled environments or self-contained solutions, having an extension own the layout is valid.

#### Optional Blocks

When referencing blocks by string name, you can append `?` to make the block **optional**:

```javascript
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

**Entry Key Validation:**
```javascript
// If you write:
{ block: MyBlock, conditon: [...] }  // typo: "conditon"

// You get:
// Error: Unknown entry key: "conditon" (did you mean "conditions"?)
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
{ block: MyBlock, args: { children: [...], args: {...}, block: "name", containerArgs: {...} } }

// You get:
// Error: Reserved arg names: args, block, children, containerArgs. Names starting with
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
import { debugHooks } from "discourse/lib/blocks/debug-hooks";

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

**Condition type registration (internal):**
```javascript
import {
  _registerConditionType,
  _freezeConditionTypeRegistry,
  isConditionTypeRegistryFrozen,
  hasConditionType,
  getConditionTypeRegistry,
} from "discourse/lib/blocks/registration";
```

> :exclamation: **Important:** Condition types must be registered before the `"freeze-block-registry"` initializer runs. Use `api.registerBlockConditionType()` in a pre-initializer for custom conditions.

These are used by dev tools and test infrastructure. They're not part of the public API and may change without notice.

**Performance: Leaf Block Caching**

Leaf blocks (blocks without children) are cached to prevent unnecessary recreation during navigation. When a user navigates between pages, previously rendered leaf blocks are reused if their component class and args haven't changed. This optimization is transparent to developers—blocks behave the same, just render faster.

---

## 3. The Evaluation Engine

We've covered registration, configuration, and the internal machinery. Now let's look at the heart of the system: how does a block decide whether to show itself?

### How Decisions Are Made

When a `<BlockOutlet>` renders, it needs to decide which blocks to show. This happens in the `#preprocessEntries` method, which implements **bottom-up evaluation**.

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
for each entry in layout:
  1. Resolve block reference (string name → class)
  2. Evaluate entry's own conditions
  3. If container with children:
     a. Recursively preprocess children (this computes their visibility)
     b. Check if any child is visible
  4. Set __visible = conditions passed AND (not container OR has visible children)
  5. If not visible, set __failureReason for debug display
```

### The Resolution Phase

Before conditions can be evaluated, block references must be resolved. The resolution phase handles three types of references:

**String Name Resolution:**
```javascript
// String reference → registry lookup
{ block: "discourse-analytics:stats-panel" }
// System looks up "discourse-analytics:stats-panel" in blockRegistry Map
// Returns the registered component class
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

The resolution cache (`factoryCache` Map) stores resolved classes to avoid repeated async loads. Once resolved, a factory never executes again—the cached class is returned directly.

### Condition Evaluation Details

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

**Visibility Flag Assignment:**

Each entry receives two internal properties after evaluation:

- `__visible` (`boolean`) - Whether the block should render
- `__failureReason` (`string | null`) - Why it's hidden (for debug tools)

Failure reasons include:
- `"conditions_failed"` - Block's own conditions returned false
- `"no_visible_children"` - Container has no visible children
- `"not_registered"` - Optional block not found in registry

**Container Visibility Logic:**

Container blocks have an implicit condition: they only render if at least one child is visible. This prevents empty container wrappers from appearing in the DOM:

```javascript
// Container visibility calculation
const ownConditionsPassed = evaluateConditions(entry.conditions);
const hasVisibleChildren = entry.children?.some(c => c.__visible);
entry.__visible = ownConditionsPassed && (isContainer ? hasVisibleChildren : true);
```

### Caching Behavior

The Block API caches leaf blocks to optimize navigation performance.

**What Gets Cached:**

Leaf blocks (blocks without children) are cached based on:
- Component class reference
- Serialized args object

When a user navigates between pages, if a leaf block's class and args match a cached entry, the cached component is reused instead of creating a new one.

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

### Reactive Re-evaluation Triggers

Conditions can depend on reactive state. When that state changes, the block tree re-evaluates.

**What Triggers Re-evaluation:**

- **Route transitions** - Navigating to a new page triggers re-evaluation of route conditions
- **User state changes** - Logging in/out, trust level changes, group membership changes
- **Site settings changes** - If a setting used in a condition is modified (rare at runtime)
- **Outlet args changes** - When parent component updates outlet args
- **Viewport changes** - Resizing browser window (for viewport conditions)

**How Re-evaluation Works:**

1. Tracked property changes notify Ember's reactivity system
2. BlockOutlet's `children` getter (which calls `#preprocessEntries`) re-runs
3. All conditions re-evaluate with current state
4. Components update based on new `__visible` flags

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

> :bulb: This example uses condition combinators (`any`, `not`, nested arrays) to build complex logic. See **Section 6: Conditions & Logic** for the complete syntax reference on combining conditions.

That covers how the evaluation engine works. But what happens when you make a mistake configuring blocks?

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

Start simple, add complexity only when you need it. You don't have to master conditions to render a block, and you don't have to master combinators to use a single condition. For complete condition syntax, see **Section 6: Conditions & Logic**.

### More Error Message Examples

Here are additional error messages you might encounter, organized by category:

**Registration Errors:**

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

**Args Validation Errors:**

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

**Outlet Errors:**

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

**Constraint Errors:**

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

**Container/Child Errors:**

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

### Development vs Production Behavior

The Block API behaves differently in development and production environments:

| Aspect | Development | Production |
|--------|-------------|------------|
| Error messages | Verbose with suggestions | Minimal, logged to console |
| Ghost blocks | Shown (if overlay enabled) | Hidden |
| Condition logging | Available | Disabled |
| Validation timing | Boot time + runtime | Boot time only |

**Enabling Debug Mode:**

Debug features are controlled via the dev tools toolbar. In production builds, the toolbar is hidden by default. To access debug tools in production:

1. Open browser DevTools console
2. Run: `Discourse.__container__.lookup("service:dev-tools-state").setProperty("enabled", true)`
3. Refresh the page

> :warning: Debug mode adds performance overhead. Use only for debugging, not routine production use.

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
  │  └─ ✓ route { pages: ["DISCOVERY_PAGES"] }

[Blocks] ✗ SKIPPED admin-banner in homepage-blocks
  ├─ ✗ AND (2 conditions)
  │  ├─ ✗ user { admin: true }
  │  └─ ─ route { pages: ["DISCOVERY_PAGES"] }  // not evaluated (short-circuit disabled in debug)
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
>   - route (pages: ["DISCOVERY_PAGES"])
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
   - Are page types matching? (`CATEGORY_PAGES` vs actual category page)
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

### Visual Reference

The following sections describe what each debug tool looks like when enabled.

#### The Dev Tools Toolbar

The Block Debug button appears in the dev tools toolbar (left side of screen). Clicking it reveals a dropdown with three toggleable options:

```
┌─────────────────────────────────┐
│ ☐ Console Logging              │
│ ☐ Visual Overlay               │
│ ☐ Outlet Boundaries            │
└─────────────────────────────────┘
```

The button icon highlights when any option is enabled.

> :bulb: **Screenshot opportunity:** The dev tools toolbar with Block Debug dropdown expanded showing the three checkbox options.

#### Rendered Block Badges

When Visual Overlay is enabled, rendered blocks display an orange badge in their top-left corner:

```
┌─────────────────────────────────────────┐
│ 🧊 hero-banner                          │
├─────────────────────────────────────────┤
│                                         │
│     [Block content appears here]        │
│                                         │
└─────────────────────────────────────────┘
```

The badge is styled with:
- Orange background
- Small cube icon
- Block name in white text
- Positioned in top-left corner with cut corner

> :bulb: **Screenshot opportunity:** A rendered block with the orange badge visible in the top-left corner.

#### Block Tooltips

Clicking a badge opens an interactive tooltip with full block details:

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

The tooltip shows:
- Block name and outlet location
- Render status (RENDERED or HIDDEN)
- Condition tree with pass/fail indicators
- Args passed from configuration
- Outlet args from template context

> :bulb: **Screenshot opportunity:** An expanded block tooltip showing conditions, arguments, and outlet args.

#### Ghost Block Placeholders

Hidden blocks appear as ghost placeholders with a distinctive appearance:

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

Ghost styling includes:
- Red dashed border
- Red diagonal stripe pattern
- Red badge with "(hidden)" suffix
- Minimum height to ensure visibility

> :bulb: **Screenshot opportunity:** A ghost block placeholder with red dashed border and diagonal stripes.

#### Ghost Tooltip with Failure Reason

Ghost block tooltips explain why the block is hidden:

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
│                                         │
│ Hint: This block is not rendered        │
│ because its conditions failed.          │
└─────────────────────────────────────────┘
```

> :bulb: **Screenshot opportunity:** A ghost block tooltip explaining why the block is hidden with the failed condition highlighted.

#### Outlet Boundaries

When Outlet Boundaries is enabled, outlets show amber borders even when empty:

```
┌─────────────────────────────────────────┐
│ 🧊🧊 homepage-blocks (3 blocks)         │
├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤
│                                         │
│     [Rendered blocks appear here]       │
│                                         │
└─────────────────────────────────────────┘
```

Outlet boundary styling:
- Amber dashed border
- Amber badge with multiple-cubes icon
- Shows block count
- Minimum height even when empty

> :bulb: **Screenshot opportunity:** An outlet with amber dashed boundary and badge showing "3 blocks".

#### Console Logging Output

The console output uses colors and collapsible groups:

```
▼ [Blocks] ✓ RENDERED hero-banner in homepage-blocks
    ✓ AND (2 conditions)
      ✓ user { loggedIn: true }
      ✓ route { pages: ["DISCOVERY_PAGES"] }

▼ [Blocks] ✗ SKIPPED admin-banner in homepage-blocks
    ✗ AND (2 conditions)
      ✗ user { admin: true }
        actual: false, required: true
      ─ route { ... } (not evaluated)
```

Console styling:
- ✓ = green
- ✗ = red
- AND/OR/NOT = blue
- Block names = bold white
- Hints = yellow italic

> :bulb: **Screenshot opportunity:** Browser console showing collapsible block evaluation logs with colored checkmarks and X marks.

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

The Block API debug tools complement browser DevTools:

**Using with Elements panel:**
1. Enable Visual Overlay
2. Click a block badge
3. Right-click tooltip → "Inspect Element"
4. Now you're inspecting the block's DOM node

**Using with Console panel:**
1. Enable Console Logging
2. Expand a block's log group
3. Click object references to inspect full objects
4. Use `copy()` to copy values to clipboard

**Using with Network panel:**
- Monitor lazy-loaded block imports
- Check if factory functions trigger network requests
- Verify block chunks load correctly

You've got the tools to see what's happening. Now you need to know what all those condition types actually do.

---

## 6. Conditions & Logic

We've mentioned conditions throughout this document. Now let's cover each one in detail—what it checks, what options it accepts, and when to use it.

### Available Conditions

#### Route Condition

Evaluates based on the current URL path, semantic page types, route parameters, and query parameters.

```javascript
{ type: "route", urls: [...], pages: [...], params: {...}, queryParams: {...} }
```

> **Why URLs instead of Ember route names?** Using internal route names like `discovery.latest` would make them part of the public API—any rename would break plugins and themes. URLs are already effectively public: changing them breaks bookmarks, external links, and SEO. By matching URLs, we avoid coupling blocks to Discourse's internal routing structure.

**Two approaches:** The route condition supports two complementary approaches:
- **`urls`**: Match URL patterns using glob syntax
- **`pages`**: Match semantic page types with typed parameters

**URL Patterns (`urls` option):**

Uses [picomatch](https://github.com/micromatch/picomatch) glob syntax:
- `"/latest"` - Exact path match
- `"/c/*"` - Single segment wildcard (`/c/foo` but not `/c/foo/bar`)
- `"/c/**"` - Multi-segment wildcard (`/c/foo`, `/c/foo/bar`, `/c/foo/bar/baz`)
- `"/t/*/**"` - Combined (`/t/123/slug`, `/t/123/slug/4`)
- `"/{latest,top}"` - Brace expansion (matches either)

**Semantic Page Types (`pages` option):**

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

**URLs vs Pages:**

Pages are preferred when you want to match page types regardless of URL structure. URLs are preferred when you need specific path patterns.

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

The `params` object supports `any` (OR) and `not` (NOT) operators for complex matching:

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

### Context Awareness

Conditions receive a context object with access to several data sources:

**Outlet Args:**
```javascript
// Passed from BlockOutlet
<BlockOutlet @name="topic-blocks" @outletArgs={{hash topic=this.topic}} />

// Accessible in conditions via source or outletArg condition
{ type: "outletArg", path: "topic.closed", value: true }
{ type: "user", source: "@outletArgs.topicAuthor", admin: true }
```

**Services (via injection in custom conditions):**
```javascript
// Inside a custom condition class
@service router;
@service currentUser;
@service siteSettings;
@service capabilities;
```

**Debug context (when logging is enabled):**
```javascript
context.debug = true;
context._depth = 2;  // Nesting level for log indentation
context.logger = { ... }; // Interface for structured logging
```

### Combining Conditions

**AND logic (array):**
```javascript
conditions: [
  { type: "user", loggedIn: true },
  { type: "route", pages: ["DISCOVERY_PAGES"] }
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
import { BlockCondition } from "discourse/blocks/conditions";
import { blockCondition } from "discourse/blocks/conditions/decorator";
import { service } from "@ember/service";

@blockCondition({
  type: "feature-flag",
  validArgKeys: ["flag", "enabled"],
})
export default class FeatureFlagCondition extends BlockCondition {
  @service featureFlags;

  /**
   * Validates condition arguments. Returns an error object if invalid, null if valid.
   *
   * @param {Object} args - The condition arguments.
   * @returns {{ message: string, path?: string } | null} Error info or null if valid.
   */
  validate(args) {
    // Always check base class validation first
    const baseError = super.validate(args);
    if (baseError) {
      return baseError;
    }

    if (!args.flag) {
      return { message: "FeatureFlagCondition: `flag` argument is required.", path: "flag" };
    }

    return null;  // Valid
  }

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

You've seen the individual pieces. Time to watch them work together.

---

## 7. Practical Patterns

Enough theory—let's build some blocks. This section covers common architectural patterns and tutorials that progress from simple to complex.

### Common Patterns

Different scenarios call for different approaches. Here are the common patterns:

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

**Pattern B: Self-Contained Plugin**

Plugin owns a specific outlet no one else needs:

```
plugins/my-plugin/     → api.registerBlock(MyPanel)
                       → api.renderBlocks("my-plugin-outlet", [...])
```

Works when the outlet is truly plugin-specific.

**Anti-Pattern: Competing for the Same Outlet**

```
plugins/plugin-a/      → api.renderBlocks("homepage-blocks", [...])  // Claims it
plugins/plugin-b/      → api.renderBlocks("homepage-blocks", [...])  // ERROR!
```

If two plugins call `renderBlocks()` on the same outlet, the second fails. Solution: plugins register, themes compose.

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
import { block } from "discourse/components/block-outlet";
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

**Step 2: Configure panels for different categories**

```javascript
// themes/my-theme/javascripts/discourse/api-initializers/category-panels.js
import { apiInitializer } from "discourse/lib/api";
import InfoPanel from "../blocks/info-panel";

export default apiInitializer((api) => {
  api.renderBlocks("category-sidebar-blocks", [
    // Support category: show help resources
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

    // Announcements category: show posting guidelines
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

    // Development categories: show API docs link
    {
      block: InfoPanel,
      args: {
        title: "Developer Resources",
        content: "Visit our API documentation for technical details.",
        icon: "code",
      },
      conditions: [
        {
          type: "route",
          pages: ["CATEGORY_PAGES"],
          params: { any: [{ categorySlug: "dev" }, { categorySlug: "plugins" }, { categorySlug: "themes" }] },
        },
      ],
    },

    // All categories except meta: show community welcome
    {
      block: InfoPanel,
      args: {
        title: "Welcome!",
        content: "Be respectful and help each other learn.",
        icon: "heart",
      },
      conditions: [
        { type: "route", pages: ["CATEGORY_PAGES"], params: { not: { categorySlug: "meta" } } },
        { type: "user", loggedIn: false },
      ],
    },
  ]);
});
```

**Step 3: Access category data via outlet args**

You can also use outlet args to access the current category directly:

```javascript
// Panel that shows category-specific rules from outlet args
{
  block: InfoPanel,
  args: {
    title: "Category Rules",
    content: "Please read the pinned topics before posting.",
    icon: "list-check",
  },
  conditions: [
    // Show only if category has custom rules defined
    { type: "outletArg", path: "category.custom_fields.has_rules", value: true },
  ],
}
```

**What we accomplished:**
- Created a reusable panel component for larger UI layouts
- Used route conditions with `params` to target specific categories
- Combined `any` operator to match multiple categories with one condition
- Used `not` operator to exclude specific categories
- Mixed route conditions with user conditions (staff-only, logged-out)
- Accessed category data via outlet args for dynamic content

So far we've been working within a single theme or plugin. The real power of the Block API emerges when multiple plugins provide blocks and a theme composes them into a unified layout.

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
import { block } from "discourse/components/block-outlet";

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

That's the Block API in practice. What follows is the complete reference for when you need to look something up.

---

## 8. Reference

When you know what you're looking for, start here.

### API Surface

#### Plugin API Methods

```javascript
api.registerBlock(BlockClass)
api.registerBlock("name", () => import("./block"))
api.renderBlocks(outletName, layout)
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
  childArgs: { [key]: ChildArgSchema },  // Schema for child-provided metadata (container blocks only)
  constraints: ConstraintSpec,  // Cross-arg validation rules
  validate: (args) => string | string[] | undefined,  // Custom validation
  allowedOutlets: string[],     // Glob patterns for allowed outlets
  deniedOutlets: string[],      // Glob patterns for denied outlets
}

// ArgSchema:
{
  type: "string" | "number" | "boolean" | "array",
  required?: boolean,
  default?: any,
  // For arrays:
  itemType?: "string" | "number" | "boolean",
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
}

// ChildArgSchema (extends ArgSchema):
{
  // Same properties as ArgSchema, plus:
  unique?: boolean,        // Enforce uniqueness across sibling children (primitives only)
}
```

#### Block Entry

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
| `urls` | `string[]` | URL patterns to match (glob syntax) |
| `pages` | `string[]` | Page types to match (e.g., `["CATEGORY_PAGES"]`) |
| `params` | `object` | Page-specific params (only with `pages`) |
| `queryParams` | `object` | Query params to match (works with both) |

> :bulb: **Note:** Use `{ not: { type: "route", ... } }` to exclude URLs or page types.

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

2. **Is a layout configured for the outlet?**
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

1. **"Unknown entry key"**
   - Check for typos in entry object
   - Valid keys: block, args, conditions, classNames, children, containerArgs

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

2. **Page type not matching**
   - Verify you're on the expected page type
   - Check discovery service state (category, tag, custom)

3. **Outlet args undefined**
   - Verify outlet passes args: `@outletArgs={{hash topic=this.topic}}`
   - Check path spelling in condition

### FAQ: Advanced Troubleshooting

**Q: My block renders in development but not in production. Why?**

A: Check these common causes:
1. **Bundle splitting** - Factory functions may fail if the import path is wrong in production builds. Verify the import path resolves correctly.
2. **Debug-only code** - If your block relies on debug tools being enabled, it won't work in production.
3. **Different site settings** - Production may have different settings that affect your conditions.
4. **Asset pipeline** - Ensure your block files are included in the production build.

**Q: Console shows my condition passed, but the block isn't visible. What's happening?**

A: The block may be rendered but hidden by CSS. Check:
1. Is the block inside a container that's hidden? (Container visibility depends on having visible children)
2. Is there CSS that's hiding the block's DOM element?
3. Is the block rendering empty content? (Check your template)

Also check if a parent container's conditions are failing—child visibility doesn't help if the parent is hidden.

**Q: Two plugins both want to render blocks in the same outlet. How do I resolve this?**

A: Only one caller can configure an outlet with `renderBlocks()`. The solution is the intended pattern:
1. Both plugins should `registerBlock()` only (in pre-initializers)
2. The theme should call `renderBlocks()` to compose blocks from both plugins
3. Use optional blocks (`?`) in case either plugin is disabled

If you control both plugins, consider making the outlet name plugin-specific or coordinating who calls `renderBlocks()`.

**Q: How do I pass data from my block back to the parent component?**

A: Blocks are one-way data flow (parent → block). For communication back:
1. **Services** - Use a shared service to communicate state
2. **Actions** - Pass action closures through outlet args: `@outletArgs={{hash onSave=this.handleSave}}`
3. **Events** - Use Ember's event system or custom events

Avoid trying to modify outlet args directly—they're passed by value.

**Q: Can I dynamically change which blocks render after boot?**

A: No. Block layouts are configured at boot time and frozen. For dynamic visibility:
1. **Use conditions** - Blocks can appear/disappear based on reactive state
2. **Use outlet args** - Pass dynamic data that conditions can check
3. **Use multiple outlets** - Different outlets for different contexts

If you need truly dynamic layout changes, plugin outlets may be more appropriate.

### Testing Strategies

#### Unit Testing Custom Conditions

Test custom conditions in isolation:

```javascript
import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import MyCustomCondition from "my-plugin/blocks/conditions/my-custom";

module("Unit | Condition | my-custom", function (hooks) {
  setupTest(hooks);

  test("evaluate returns true when feature flag is enabled", function (assert) {
    const condition = this.owner.lookup("service:blocks").instantiateCondition(MyCustomCondition);

    // Mock the service the condition depends on
    condition.featureFlags = { isEnabled: () => true };

    const result = condition.evaluate({ flag: "my-feature", enabled: true });
    assert.true(result);
  });

  test("validate returns error for missing flag", function (assert) {
    const condition = new MyCustomCondition();
    const error = condition.validate({});

    assert.ok(error);
    assert.ok(error.message.includes("flag"));
  });
});
```

#### Integration Testing Block Visibility

Test block visibility with different conditions:

```javascript
import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { withTestBlockRegistration } from "discourse/lib/blocks/registration";

module("Integration | Block | my-banner", function (hooks) {
  setupRenderingTest(hooks);

  test("renders when user is logged in", async function (assert) {
    await withTestBlockRegistration(this, async () => {
      // Register block
      this.owner.lookup("service:blocks").registerBlock(MyBanner);

      // Configure layout
      this.owner.lookup("service:blocks").renderBlocks("test-outlet", [
        {
          block: MyBanner,
          conditions: { type: "user", loggedIn: true },
        },
      ]);

      // Mock logged-in user
      this.owner.register("service:current-user", {
        create: () => ({ id: 1, username: "test" }),
      });

      await render(hbs`<BlockOutlet @name="test-outlet" />`);

      assert.dom(".my-banner").exists();
    });
  });

  test("does not render when user is anonymous", async function (assert) {
    await withTestBlockRegistration(this, async () => {
      // ... similar setup but no current-user mock

      await render(hbs`<BlockOutlet @name="test-outlet" />`);

      assert.dom(".my-banner").doesNotExist();
    });
  });
});
```

#### Testing with Mock Outlet Args

```javascript
test("uses topic data from outlet args", async function (assert) {
  await withTestBlockRegistration(this, async () => {
    // ... register and configure block

    this.set("mockTopic", { id: 123, title: "Test Topic" });

    await render(hbs`
      <BlockOutlet
        @name="test-outlet"
        @outletArgs={{hash topic=this.mockTopic}}
      />
    `);

    assert.dom(".topic-title").hasText("Test Topic");
  });
});
```

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

## 9. Glossary

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

---

*This documentation is generated from source code analysis and may be updated as the API evolves.*
