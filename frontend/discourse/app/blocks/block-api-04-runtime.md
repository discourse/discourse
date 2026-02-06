# Block API: Runtime

> **Navigation:** [Getting Started](block-api-getting-started.md) | [Concepts](block-api-01-concepts.md) | [Architecture](block-api-02-architecture.md) | [Conditions](block-api-03-conditions.md) | **Runtime** | [Internals](block-api-05-internals.md) | [Reference](block-api-06-reference.md) | [Authoring](block-api-authoring.md)

---

When a `<BlockOutlet>` renders, it kicks off a decision process. The system doesn't just check conditions top-to-bottom—it uses **bottom-up evaluation** to handle containers correctly. This is the heart of the rendering pipeline.

---

## How Decisions Are Made

The key insight is **bottom-up evaluation**—children are processed before parents.

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

**The algorithm:**

```
for each entry in layout:
  1. Resolve block reference (string name → class)
  2. Evaluate entry's own conditions
  3. If container with children:
     a. Recursively preprocess children (this computes their visibility)
     b. Check if any child is visible
  4. Mark visible if conditions passed AND (not container OR has visible children)
  5. If not visible, record the reason for debug tools
```

---

## Block Resolution

Before conditions can be evaluated, block references must be resolved.

### String Name Resolution

```javascript
// String reference → registry lookup
{ block: "discourse-analytics:stats-panel" }
// System looks up the name in the block registry and returns the component class
```

### Factory Function Resolution

Factory functions enable lazy loading for code splitting. Declare during registration, reference by string name in layouts:

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

**Incorrect usage:**
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

**Correct approach:**
```javascript
// ✓ Good: Register both, use conditions to select
api.registerBlock(BlockA);
api.registerBlock(BlockB);

api.renderBlocks("outlet", [
  { block: BlockA, conditions: { type: "setting", name: "feature_a", enabled: true } },
  { block: BlockB, conditions: { type: "setting", name: "feature_a", enabled: false } },
]);
```

### Optional Block Handling

```javascript
// Optional marker (?) affects resolution behavior
{ block: "some-plugin:optional-block?" }
// If not found in registry:
//   - Without ?: throw BlockError
//   - With ?: return null, mark entry as optional
```

---

## Condition Evaluation

After resolution, conditions are evaluated.

### Short-Circuit Evaluation

When debug mode is disabled, conditions short-circuit—AND stops on first failure, OR stops on first success:

```javascript
conditions: [
  { type: "user", admin: true },      // If false → skip rest
  { type: "route", pages: ["ADMIN"] }, // Never evaluated if admin check failed
  { type: "setting", name: "x" }       // Never evaluated
]
```

In debug mode, short-circuiting is disabled so you see the complete evaluation picture.

### Visibility Flags

After evaluation, each entry is marked with:
- **Visibility** — Whether the block should render
- **Failure reason** — Why it's hidden (shown in debug tools)

Failure reasons include:
- Condition failed — Block's own conditions returned false
- No visible children — Container has no visible children

### Container Visibility Logic

Container blocks have an implicit condition: they only render if at least one child is visible. This prevents empty container wrappers from appearing in the DOM.

```
visible = ownConditionsPassed AND (notContainer OR hasVisibleChildren)
```

---

## Caching Behavior

The Blocks API caches leaf blocks to optimize navigation performance.

### What Gets Cached

Leaf blocks (blocks without children) are cached based on:
- Component class reference
- Args object (compared using shallow equality)

When a user navigates between pages, if a leaf block's class and args match a cached entry, the cached component is reused.

### What Doesn't Get Cached

Container blocks are never cached because:
- Their children may have different visibility on different pages
- The children array is route-dependent
- Re-evaluating children is necessary for correctness

### Cache Invalidation

The cache invalidates when:
- Args change (even if component class is the same)
- Component class changes
- App is refreshed

This caching is transparent—your block code doesn't need to account for it.

---

## What Makes Blocks Update

Conditions can depend on reactive state. When that state changes, the block tree re-evaluates.

### Triggers

- **Route transitions** — Navigating to a new page
- **User state changes** — Logging in/out, trust level changes, group membership changes
- **Site settings changes** — If a setting used in a condition is modified
- **Outlet args changes** — When parent component updates outlet args
- **Viewport changes** — Resizing browser window (for viewport conditions)

### How Re-evaluation Works

1. Tracked property changes notify Ember's reactivity system
2. BlockOutlet re-evaluates the block tree
3. All conditions re-evaluate with current state
4. Components update based on new visibility state

### Minimizing Re-renders

To keep re-evaluation efficient:
- Avoid complex conditions when simple ones suffice
- Keep container hierarchies shallow

---

## Step-by-Step Evaluation Example

Let's trace through a complex condition tree:

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

---

## Performance Considerations

### Condition Evaluation Cost

Conditions are evaluated at render time. Built-in conditions are highly optimized, but costs can add up:

- **Deeply nested conditions** create more function calls
- **Large outlets** take proportionally longer to evaluate
- **Reactive triggers** that change frequently cause re-evaluation

In practice, you're unlikely to hit performance problems with typical layouts. If you notice sluggishness, enable debug mode to see which conditions are being evaluated.

### Container Depth Limits

Layouts cannot nest deeper than 20 levels. Hitting this limit usually indicates a design issue—most layouts work well with 2-3 levels.

### Caching

Several aspects are cached for performance:

- **Block classes** from factory functions are cached permanently after first resolution
- **Condition type classes** are looked up once and cached
- **Outlet layouts** are preprocessed once per navigation

### CSS Media Queries vs Viewport Conditions

For simple show/hide based on screen size, CSS media queries are usually more performant:

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
- **Combine viewport checks with other conditions**

---

## When Things Go Wrong

The Blocks API catches mistakes early and explains them clearly. Most validation happens at boot time, surfacing problems before users ever see a broken page.

### Error Message Examples

**Unknown keys with suggestions:**
```
[Blocks] Invalid block entry at blocks[0] for outlet "homepage-blocks":
Unknown entry key: "conditon" (did you mean "conditions"?).
Valid keys are: block, args, children, conditions, containerArgs.

Location:
└─ [0] MyBlock
   └─ conditon  ← error here
```

**Type mismatches:**
```
[Blocks] BlockUserCondition: `minTrustLevel` must be a number between 0 and 4.
```

**Logical impossibilities:**
```
[Blocks] BlockUserCondition: `minTrustLevel` (4) cannot be greater than
`maxTrustLevel` (2). No user can satisfy this condition.
```

**Unknown condition types:**
```
[Blocks] Unknown condition type: "usr" (did you mean "user"?).
Available types: route, user, setting, viewport, outlet-arg
```

**Registration errors:**
```
[Blocks] Block "theme:my-theme:banner" is already registered.
Each block name must be unique across all plugins and themes.
```

**Args validation:**
```
[Blocks] Block "my-block" at blocks[0]:
Unknown arg "tite" (did you mean "title"?).
Declared args: title, subtitle, variant
```

**Outlet configuration:**
```
[Blocks] Outlet "homepage-blocks" is already configured.
First configured by: my-theme/api-initializers/layout.js:8
Only one caller can configure an outlet.
```

**Constraint violations:**
```
[Blocks] Block "featured-list" at blocks[0]:
At least one of "categoryId", "tagName" must be provided, but got none.
```

### Validation Feedback

Errors in nested conditions include the full path:

```
[Blocks] Invalid conditions for block "my-block":
Condition type "route": unknown arg "querParams" (did you mean "queryParams"?).

Location: blocks[0].conditions.any[0].not.querParams
```

---

## Your Debugging Toolkit

The Blocks API includes visual and console-based tools to help you understand what's happening at runtime.

### Available Tools

| Tool | What it does | How to enable |
|------|--------------|---------------|
| **Console Logging** | Logs condition evaluations to browser console | Toggle "Block Debug" in toolbar |
| **Visual Overlay** | Shows block boundaries with badges and tooltips | Toggle "Block Overlay" in toolbar |
| **Outlet Boundaries** | Shows outlet boundaries even when empty | Toggle "Outlet Boundaries" in toolbar |
| **Ghost Blocks** | Shows hidden blocks as dashed placeholders | Enabled with Visual Overlay |

### Accessing the Tools

The debug tools live in the dev tools toolbar. Click the Block Debug button to reveal toggleable options:

```
┌─────────────────────────────────┐
│ ☐ Console Logging               │
│ ☐ Visual Overlay                │
│ ☐ Outlet Boundaries             │
└─────────────────────────────────┘
```

**Development vs Production:**

In development builds, the toolbar is visible by default. In production:

```javascript
enableDevTools()   // stores preference, reloads page
disableDevTools()  // removes preference, reloads page
```

> :warning: Debug mode adds performance overhead. Use for debugging, not routine production use.

### Console Logging

Every time a block renders (or doesn't), you'll see a collapsible log entry:

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

When debug logging is enabled, the system evaluates *all* conditions—even after one fails—so you get the complete picture.

### Visual Overlay

Every rendered block gets an orange badge showing the block name. Click a badge for a tooltip with:
- Status (rendered or hidden)
- Conditions and whether they passed
- Arguments passed to the block
- Available outlet args

### Ghost Blocks

Ghost blocks show where blocks *would* render if their conditions had passed—a red dashed outline with diagonal stripes. Click the badge to see why it's hidden:
- "conditions failed" for regular blocks
- "no visible children" for containers
- "not registered" for optional blocks from uninstalled plugins

### Outlet Boundaries

Shows where outlets are, even when empty or with no visible blocks. Each outlet gets an amber dashed border with a badge showing its name and block count.

---

## Debugging Workflows

### "I can't see my block"

1. Enable **Console Logging** in dev tools
2. Navigate to the page where the block should appear
3. Look for your block in the console:
   - `✗ SKIPPED` — Your conditions are the issue
   - Not logged at all — Block not registered or outlet not configured
4. Enable **Visual Overlay** and **Outlet Boundaries**
5. Check what appears: a ghost means conditions failed; nothing at all means the block isn't configured

### "My condition isn't working"

1. Enable **Console Logging**
2. Expand the log for your block
3. Check the condition tree—is the type correct? Are arguments what you expect?
4. For route conditions, verify:
   - Current URL matches expectations
   - Page types are resolving correctly
   - Query params are actually present

### "I'm not sure what's happening"

1. Enable all debug tools
2. Open browser DevTools console
3. Navigate through the app and watch:
   - Which blocks render or skip on each page
   - What conditions are evaluated
   - How actual values compare to configuration

### Common Issues

| Symptom | Check This |
|---------|------------|
| Block missing | Is outlet boundary visible? Is block in console logs? |
| Ghost but expected visible | Expand console log, check which condition failed |
| Visible but expected hidden | Check if all conditions are present in config |
| Works locally, not in prod | Are debug tools enabled? Check production build |

### Tips

**Identifying configuration vs condition issues:**
- Block not in console at all → Registration or layout configuration issue
- Block logged as SKIPPED → Condition issue
- Block logged as RENDERED but not visible → CSS or DOM issue

**Using the Args Table:**

Clicking rows in the Arguments tables saves values to global console variables:

```javascript
// After clicking @title row in tooltip:
arg1 // → "Welcome"

// After clicking @outletArgs.topic row:
arg2 // → Topic { id: 123, title: "...", ... }
```

---

> **Next:** [Internals](block-api-05-internals.md) — The blocks service, registry, and preprocessing pipeline
