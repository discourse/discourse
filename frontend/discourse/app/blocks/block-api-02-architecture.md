# Block API: Architecture

> **Navigation:** [Getting Started](block-api-getting-started.md) | [Concepts](block-api-01-concepts.md) | **Architecture** | [Conditions](block-api-03-conditions.md) | [Runtime](block-api-04-runtime.md) | [Internals](block-api-05-internals.md) | [Reference](block-api-06-reference.md) | [Authoring](block-api-authoring.md)

---

This section covers *how* to work with blocks. We'll cover the `@block` decorator, the `<BlockOutlet>` component, and the `renderBlocks()` function.

## Blocks and Plugin Outlets

When should you use blocks versus plugin outlets? They serve different purposes:

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

---

## Registering and Composing

By design, the Blocks API separates **registering blocks** from **composing layouts**. Plugins sometimes need to compose layouts, and themes sometimes provide blocks. Here's the mental model:

**Core** provides built-in blocks—pre-registered and always available:
- `group`: A general-purpose container for organizing related blocks
- `head`: A conditional container for "if/else" logic (renders first matching child)

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

---

## Built-in Blocks

Core provides container blocks that you can use without registration.

### The `group` Block

The `group` block organizes related blocks together. It renders all visible children in sequence, wrapped in a styled container element.

```javascript
@block("group", {
  container: true,
  description: "Groups multiple children blocks together",
})
```

The `id` entry property (not an arg) identifies the group for styling and debugging. It generates CSS classes like `{outletName}__block-container--{id}`.

**Usage example:**
```javascript
api.renderBlocks("homepage-blocks", [
  {
    block: "group",
    id: "featured",
    children: [
      { block: PromoBanner },
      { block: FeaturedTopics },
    ],
  },
  {
    block: "group",
    id: "recent",
    children: [
      { block: RecentActivity },
      { block: TrendingTags },
    ],
  },
]);
```

This creates two distinct visual sections you can style via CSS:
```css
.homepage-blocks__block-container--featured {
  background: var(--tertiary-low);
  padding: 2rem;
}

.homepage-blocks__block-container--recent {
  border-top: 1px solid var(--primary-low);
}
```

### The `head` Block

The `head` block implements conditional branching—like a switch statement, it evaluates children in order and renders only the first one whose conditions pass.

```javascript
@block("head", {
  container: true,
  description: "Renders only the first child whose conditions pass",
})
```

**Usage example (showing different content based on user state):**
```javascript
api.renderBlocks("welcome-area", [
  {
    block: "head",
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

The order matters: the first matching child wins. In this example, admins see `AdminDashboard`, moderators (who aren't admins) see `ModeratorTools`, logged-in members see `MemberWelcome`, and anonymous visitors see `GuestWelcome`.

### Choosing Between `group`, `head`, and Direct Conditions

| Scenario | Use This | Why |
|----------|----------|-----|
| Multiple blocks that should all render together | `group` | Groups related content, provides a styled container |
| Mutually exclusive alternatives (only one should render) | `head` | Evaluates in order, renders only the first match |
| Independent blocks with unrelated conditions | Direct conditions | Each block stands alone, simpler to configure |
| A default fallback when nothing else matches | `head` | Last child without conditions catches everything |

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
    block: "head",
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
    id: "featured",
    children: [
      { block: HeroBanner },
      { block: FeaturedTopics },
    ],
  },
]
// Both children render (if their conditions pass), wrapped in a styled container.
```

---

## Composing Layouts

The `renderBlocks()` function configures which blocks appear in an outlet:

```javascript
api.renderBlocks("homepage-blocks", [
  { block: Banner, args: { title: "Welcome" } },
  { block: "analytics:stats-panel?" },  // Optional block from plugin
  { block: Sidebar, conditions: { type: "user", loggedIn: true } },
]);
```

Blocks can be referenced two ways:
- **By class** - Import and pass directly: `{ block: Banner }`
- **By name** - Use the registered string name: `{ block: "analytics:stats-panel" }`

String names enable cross-plugin references where you can't import the class directly.

### Optional Blocks

When using string names, append `?` to make the block **optional**:

```javascript
api.renderBlocks("dashboard", [
  { block: "analytics:stats-panel?" },  // Optional - won't error if missing
  { block: "chat:recent-messages?" },   // Optional
  { block: "gamification:scores" },     // Required - will error if not registered
  { block: CoreBanner },                // Static import
]);
```

**Why optional blocks?**

Themes often compose blocks from multiple plugins, but those plugins may not be installed or could be disabled.

| Scenario | Required Block | Optional Block (`?`) |
|----------|----------------|----------------------|
| Block registered | ✓ Renders | ✓ Renders |
| Block not registered | ✗ Error thrown | ✓ Silently skipped |
| Plugin disabled | ✗ Error thrown | ✓ Silently skipped |

**When to use optional blocks:**
- Theme referencing plugin blocks (plugins may not be installed)
- Cross-plugin integration (Plugin A uses Plugin B's block if available)
- Graceful degradation (dashboard that works with any subset of plugins)

**When NOT to use optional blocks:**
- Block you own (if you register and render the same block, it should always exist)
- Core blocks (always available)
- Required dependencies (fail loudly if essential)

> :bulb: In debug mode, optional missing blocks appear as ghost placeholders with the message "This optional block is not rendered because it's not registered."

### Outlet Ownership

Each outlet can only have one `renderBlocks()` configuration—the first caller owns it, and subsequent calls raise an error. While themes typically compose layouts, plugins and theme components *can* call `renderBlocks()` when they need full control of an outlet.

This works well for self-contained plugins that own specific UI areas, turnkey solutions providing a complete experience, or heavily customized instances where extensions are coordinated.

---

## Architectural Patterns

### Pattern A: Theme Composes Plugin Blocks (Recommended)

Plugins register blocks, theme arranges them:

```
plugins/analytics/     → api.registerBlock(StatsPanel)
plugins/tasks/         → api.registerBlock(TaskList)
themes/my-theme/       → api.renderBlocks("homepage-blocks", [
                           { block: "analytics:stats-panel?" },
                           { block: "tasks:task-list?" },
                         ])
```

This is the recommended approach because it keeps plugins interoperable. Each plugin focuses on functionality; the theme decides presentation.

### Pattern B: Self-Contained Plugin

Plugin owns a specific outlet no one else needs:

```
plugins/my-plugin/     → api.registerBlock(MyPanel)
                       → api.renderBlocks("my-plugin:outlet", [...])
```

Works when the outlet is truly plugin-specific—perhaps an outlet the plugin itself creates via `registerBlockOutlet()`.

### Anti-Pattern: Competing for the Same Outlet

```
plugins/plugin-a/      → api.renderBlocks("homepage-blocks", [...])  // Claims it
plugins/plugin-b/      → api.renderBlocks("homepage-blocks", [...])  // ERROR!
```

If two plugins call `renderBlocks()` on the same outlet, the second fails. This is why Pattern A is recommended—plugins register, themes compose.

---

## Creating Blocks

The `@block` decorator transforms a Glimmer component into a block. It adds:

- **Static properties** for introspection: `blockName`, `blockMetadata`, `namespace`, `namespaceType`
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

See [Concepts: What's Inside a Block](block-api-01-concepts.md#whats-inside-a-block) for the complete decorator options including args schemas, constraints, and outlet restrictions.

---

## Adding Block Outlets

The `<BlockOutlet>` component defines where blocks render in templates. Core and plugins use this to create outlet locations that themes can then populate.

```handlebars
<BlockOutlet @name="homepage-blocks" />
```

That's the simplest form—just a named location. The outlet waits for someone to call `renderBlocks()` with its name, then renders whatever blocks are configured.

### Outlet Args

Some outlets need to pass contextual data to their blocks. A topic sidebar needs to tell blocks which topic is being viewed:

```handlebars
{{! Example: a hypothetical outlet in a topic header template }}
<BlockOutlet
  @name="topic-header-blocks"
  @outletArgs={{hash topic=this.model user=this.currentUser}}
/>
```

> :exclamation: **Key difference from plugin outlets:** In blocks, outlet args are accessed via `@outletArgs`, not `@args`. The `@args` namespace is reserved for the block's layout entry args (from `renderBlocks()`).

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

In the layout configuration:

```javascript
api.renderBlocks("topic-header-blocks", [
  {
    block: MyBlock,
    args: { title: "Related Content", variant: "highlighted" },  // becomes @title, @variant
  },
]);
```

### System Args

The block system automatically provides a system arg to all blocks:

| Arg | Type | Description |
|-----|------|-------------|
| `@outletName` | `string` | The outlet identifier this block is rendered in (e.g., `"homepage-blocks"`) |

The system uses `@outletName` internally for:
- **CSS class generation:** Wrapper classes like `{outletName}__block` for BEM-style scoping
- **Debug context:** Identifying which outlet a block belongs to in error messages

### Named Blocks: `:before` and `:after`

BlockOutlet supports Ember's named blocks for rendering content around your blocks:

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

Both named blocks receive a boolean indicating whether **any blocks are configured** for this outlet.

| Named Block | Renders | Common Uses |
|-------------|---------|-------------|
| `:before` | Before all blocks | Section headers, introductory text, "featured" labels |
| `:after` | After all blocks | Empty states, fallback content, "see more" links |

**Examples:**

```handlebars
{{! Add a header only when blocks exist }}
<BlockOutlet @name="sidebar-panels">
  <:before as |isConfigured|>
    {{#if isConfigured}}
      <h3 class="sidebar-panels__header">Panels</h3>
    {{/if}}
  </:before>
</BlockOutlet>

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
```

**Important distinction:** The boolean tells you if blocks are *configured*, not if they're *visible*. If you configure three blocks but all their conditions fail, `isConfigured` is still `true`—the outlet has configuration, it just has no visible output.

---

> **Next:** [Conditions](block-api-03-conditions.md) — User state, routes, settings, viewport, and custom conditions
