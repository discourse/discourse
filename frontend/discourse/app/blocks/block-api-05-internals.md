# Block API: Internals

> **Navigation:** [Getting Started](block-api-getting-started.md) | [Concepts](block-api-01-concepts.md) | [Architecture](block-api-02-architecture.md) | [Conditions](block-api-03-conditions.md) | [Runtime](block-api-04-runtime.md) | **Internals** | [Reference](block-api-06-reference.md) | [Authoring](block-api-authoring.md)

---

Most developers never need to look here. The public API—`@block`, `registerBlock`, `renderBlocks`, `<BlockOutlet>`—handles everything you need for building with blocks. But if you're curious about the machinery, debugging something unusual, or contributing to the Blocks API itself, this section explains what happens behind the scenes.

---

## The Blocks Service

The `blocks` service is your window into the block system at runtime. While most block work happens declaratively through configuration, sometimes you need to query the system programmatically.

```javascript
import { service } from "@ember/service";

class MyComponent extends Component {
  @service blocks;

  get availableBlocks() {
    return this.blocks.listBlocksWithMetadata();
  }
}
```

### Service Methods

**`hasBlock(name)`** — Check whether a block name is registered:

```javascript
if (this.blocks.hasBlock("discourse-analytics:stats-panel")) {
  // Safe to use the block
}
```

**`listBlocksWithMetadata()`** — Get detailed information about all registered blocks:

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

Useful for building admin interfaces that display available blocks, or for debugging tools.

The service is intentionally read-only. You can't register blocks or modify the registry through it—that happens through the plugin API during initialization.

---

## The Block Registry

Behind the service sits the block registry—a collection of Maps that track everything about registered blocks.

### Core Data Structures

**Primary registry** — Maps block names to their entries:

```javascript
// Conceptually:
blockRegistry = Map {
  "theme:my-theme:banner" => BannerComponent,
  "discourse-analytics:stats-panel" => () => import("./stats-panel"),
  "group" => GroupComponent,
}
```

**Factory cache** — Stores resolved classes for lazy-loaded blocks:

```javascript
// After first resolution:
factoryCache = Map {
  "discourse-analytics:stats-panel" => StatsPanelComponent,
}
```

**Pending resolutions** — Tracks in-flight Promise resolutions to prevent duplicate loads:

```javascript
// During resolution:
pendingResolutions = Map {
  "discourse-analytics:stats-panel" => Promise<StatsPanelComponent>,
}
```

**Failed resolutions** — Remembers which factories have failed to prevent retry loops:

```javascript
failedResolutions = Set {
  "missing-plugin:broken-block",
}
```

### The Freeze Mechanism

The registry has two states: unfrozen and frozen.

During application boot, pre-initializers run with the registry unfrozen—this is when all `registerBlock()` calls must happen. After the `freeze-block-registry` initializer runs, the registry freezes.

This two-phase design:
- Ensures all blocks are available before any `renderBlocks()` calls
- Makes the set of available blocks deterministic
- Catches registration timing errors early with clear error messages

```javascript
// In an api-initializer (too late!):
api.registerBlock(MyBlock);
// Error: api.registerBlock() was called after the block registry was frozen.
// Block registration must happen in pre-initializers that run before "freeze-block-registry".
```

### Namespace Enforcement

The registry tracks which source (plugin or theme) registered each namespace. This prevents naming conflicts where two plugins might accidentally use the same block name.

```javascript
// Plugin A registers:
api.registerBlock(Banner);  // "my-plugin:banner" - claims "my-plugin" namespace

// Plugin B tries:
api.registerBlock(OtherBlock);  // "my-plugin:other" - ERROR: namespace conflict
```

This enforcement happens at registration time.

---

## The Preprocessing Pipeline

When a `<BlockOutlet>` component renders, it triggers a preprocessing pipeline that transforms the layout configuration into renderable components.

### Step 1: Layout Retrieval

The outlet looks up its layout configuration from the outlet registry. If no layout was configured via `renderBlocks()`, the outlet renders nothing (or just its `:before`/`:after` named blocks if provided).

### Step 2: Block Resolution

Each block entry needs its block reference resolved to an actual component class:

- **Class references** — Immediate, class is already available
- **String references** — Registry lookup, error if not found (unless optional)
- **Factory entries** — Check cache, call factory if needed, cache result

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

### Step 3: Condition Evaluation

With all blocks resolved, the system evaluates conditions bottom-up—children before parents—because container visibility depends on having at least one visible child.

For each block entry:
1. Evaluate the entry's own conditions (if any)
2. If it's a container with children, recursively process children first
3. For containers, check if any child is visible
4. Mark the entry visible or hidden, recording the reason if hidden

### Step 4: Component Creation

For visible blocks, the system creates curried components. "Currying" means pre-binding the component's args. The currying captures:

- The block's declared args from the layout configuration
- System args like `@outletName`
- Outlet args from the `<BlockOutlet>` component
- For containers: the processed children array

### Step 5: Ghost Generation (Debug Mode)

When visual overlay debugging is enabled, hidden blocks become "ghost" placeholders that render as dashed outlines with badges explaining why the block is hidden.

---

## Validation Internals

The Blocks API validates at multiple points during the application lifecycle.

### Decoration Time

When the `@block()` decorator executes (as your JavaScript loads):

- Block name format (correct namespace pattern)
- Args schema structure (valid types, no conflicting options)
- Constraint definitions (no incompatible constraints)
- Outlet patterns (no conflicts between allowed and denied)
- Container-specific options (`childArgs` only on containers)

These errors appear as soon as the file loads.

### Registration Time

When `registerBlock()` is called:

- Duplicate name detection (with source tracking)
- Namespace ownership verification
- Registry frozen check

### Layout Configuration Time

When `renderBlocks()` is called:

- Block existence (all referenced blocks must be registered, unless optional)
- Outlet validity (the outlet name must be registered)
- Outlet ownership (no duplicate calls for same outlet)
- Entry key validation (no typos in property names)
- Args validation against schemas
- Condition validation (known types, valid args)
- Container relationships (`children` only on containers, `containerArgs` matches parent's `childArgs`)

This is where most developer errors surface.

### Render Time

By render time, most validation has already happened. Minimal checks:

- Authorization symbol verification
- Lazy block resolution (factory functions are called)

---

## Condition Discovery and Instantiation

Conditions are backed by classes that know how to evaluate themselves.

### The Condition Type Registry

Like blocks, condition types have their own registry. Built-in types (`user`, `route`, `setting`, `viewport`, `outlet-arg`) are registered by core during the `freeze-block-registry` initializer. Custom conditions must be registered in pre-initializers that run before this freeze.

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

### Condition Instantiation

The system creates one instance of each condition type per evaluation context, setting the Ember owner so service injection works:

```javascript
// Conceptually:
const userCondition = new BlockUserCondition();
setOwner(userCondition, applicationInstance);
// Now userCondition.currentUser is injected
```

These instances are reused across all condition evaluations within the same preprocessing pass.

### The Evaluation Context

When `evaluate()` is called, it receives:
- The condition's args (from the layout configuration)
- An evaluation context containing `outletArgs` and `outletName`

### The evaluate() Contract

Condition evaluation must be synchronous. The `evaluate()` method returns a boolean immediately—no Promises, no async/await.

If your condition needs async data, fetch it elsewhere (in a route, service, or component's constructor) and pass it through outlet args:

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

---

## The Authorization Symbol System

The system prevents unauthorized block rendering using a private symbol system. When blocks are defined, they receive a reference to a secret symbol. At construction time, blocks verify they received this symbol—if not, they throw an error.

### How It Works

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

The preprocessing pipeline includes this secret symbol when creating curried components. Direct template usage (`<MyBlock />`) doesn't include the symbol, so the constructor throws.

### The Chain of Trust

Container blocks pass their own authorization symbol to children, creating a chain of trust. `<BlockOutlet>` has special handling that allows it to bypass the check and initiate the chain.

This design ensures:
- Blocks only render through the official system
- Conditions are always evaluated (can't be bypassed)
- Layout configuration is always respected
- Plugin developers can't accidentally misuse blocks

---

> **Next:** [Reference](block-api-06-reference.md) — Tutorials, API tables, troubleshooting FAQ, and glossary
