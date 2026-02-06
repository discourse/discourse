# Block API: Reference

> **Navigation:** [Getting Started](block-api-getting-started.md) | [Concepts](block-api-01-concepts.md) | [Architecture](block-api-02-architecture.md) | [Conditions](block-api-03-conditions.md) | [Runtime](block-api-04-runtime.md) | [Internals](block-api-05-internals.md) | **Reference** | [Authoring](block-api-authoring.md)

---

This section provides API tables, troubleshooting guides, and a glossary for quick reference. For step-by-step tutorials, see [Authoring](block-api-authoring.md#part-10-tutorials).

---

## API Reference

### Plugin API Methods

```javascript
api.registerBlock(BlockClass)
api.registerBlock("name", () => import("./block"))
api.renderBlocks(outletName, layout)
api.registerBlockOutlet(outletName, options)
api.registerBlockConditionType(ConditionClass)
```

### The `@block` Decorator

```javascript
@block(name, options)

// Options:
{
  container: boolean,           // Can contain child blocks
  description: string,          // Human-readable description
  args: { [key]: ArgSchema },   // Argument definitions
  childArgs: { [key]: ChildArgSchema },  // Schema for child-provided metadata
  constraints: ConstraintSpec,  // Cross-arg validation rules
  validate: (args) => string | string[] | undefined,  // Custom validation
  allowedOutlets: string[],     // Glob patterns for allowed outlets
  deniedOutlets: string[],      // Glob patterns for denied outlets
}
```

### ArgSchema

| Property | Types | Description |
|----------|-------|-------------|
| `type` | all | Required: `"string"`, `"number"`, `"boolean"`, `"array"`, `"object"`, `"any"` |
| `required` | all | Must be provided |
| `default` | all | Default value |
| `minLength` | `string`, `array` | Minimum length |
| `maxLength` | `string`, `array` | Maximum length |
| `pattern` | `string` | Regex pattern |
| `min` | `number` | Minimum value |
| `max` | `number` | Maximum value |
| `integer` | `number` | Must be whole number |
| `enum` | `string`, `number` | Restrict to specific values |
| `itemType` | `array` | Type of array items |
| `itemEnum` | `array` | Restrict array items to specific values |
| `properties` | `object` | Nested property schemas |
| `instanceOf` | `object` | Class to check with `instanceof` |
| `instanceOfName` | `object` | Display name for instanceOf errors |

### ConstraintSpec

| Constraint | Description |
|------------|-------------|
| `atLeastOne` | At least one must be provided |
| `exactlyOne` | Exactly one must be provided |
| `allOrNone` | All or none must be provided |
| `atMostOne` | At most one may be provided |
| `requires` | Dependent arg requires another arg |

### Block Entry

```javascript
{
  block: BlockClass | "block-name" | "block-name?",  // Required
  args?: { [key]: any },
  conditions?: ConditionSpec | ConditionSpec[],
  id?: string,                   // For CSS targeting
  children?: BlockEntry[],       // Container blocks only
  containerArgs?: { [key]: any },
}
```

### Condition Specifications

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

---

## Condition Reference

### Route Condition

| Arg | Type | Description |
|-----|------|-------------|
| `urls` | `string[]` | URL patterns to match (glob syntax) |
| `pages` | `string[]` | Page types to match |
| `params` | `object` | Page-specific params (only with `pages`) |
| `queryParams` | `object` | Query params to match |

**Page Types:** `CATEGORY_PAGES`, `TAG_PAGES`, `DISCOVERY_PAGES`, `HOMEPAGE`, `TOP_MENU`, `TOPIC_PAGES`, `USER_PAGES`, `ADMIN_PAGES`, `GROUP_PAGES`

### User Condition

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

### Setting Condition

| Arg | Type | Description |
|-----|------|-------------|
| `name` | `string` | Setting key (required) |
| `source` | `object` | Custom settings object |
| `enabled` | `boolean` | Setting is truthy/falsy |
| `equals` | `any` | Exact value match |
| `includes` | `array` | Value is in array |
| `contains` | `string` | List contains value |
| `containsAny` | `array` | List contains any value |

### Viewport Condition

| Arg | Type | Description |
|-----|------|-------------|
| `min` | `string` | Minimum breakpoint (`sm`, `md`, `lg`, `xl`, `2xl`) |
| `max` | `string` | Maximum breakpoint |
| `touch` | `boolean` | Touch device only |

**Breakpoints:** sm (640px), md (768px), lg (1024px), xl (1280px), 2xl (1536px)

### OutletArg Condition

| Arg | Type | Description |
|-----|------|-------------|
| `path` | `string` | Dot-notation path (required) |
| `value` | `any` | Value to match |
| `exists` | `boolean` | Property existence check |

---

## Troubleshooting

### Block Not Appearing

1. **Check registration** — Look for console errors about unknown blocks or registration timing
2. **Verify layout configuration** — Did you call `renderBlocks()` with the correct outlet name?
3. **Check conditions** — Enable Console Logging and look for `✗ SKIPPED`
4. **Confirm outlet exists** — Enable Outlet Boundaries to verify the outlet is in the template

### Common Validation Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "Unknown entry key" | Typo in block entry | Check spelling; valid keys: `block`, `args`, `conditions`, `id`, `children`, `containerArgs` |
| "Unknown condition type" | Typo or unregistered condition | Check spelling; if custom, verify registration |
| "Block not registered" | Missing registration or typo | Check pre-initializer runs before freeze; use `?` for optional |
| "Cannot render in outlet" | Outlet restrictions | Check block's `allowedOutlets`/`deniedOutlets` |

### Conditions Not Working

- **Type mismatches** — Query params are always strings; use `"1"` not `1`
- **Page type confusion** — Verify you're on the expected page type in console output
- **Undefined outlet args** — Verify `<BlockOutlet>` includes `@outletArgs`

### FAQ

**Q: Block renders in dev but not in production?**
- Check factory import paths resolve correctly
- Verify site settings are the same

**Q: Console shows condition passed but block not visible?**
- Check parent container visibility
- Check for CSS hiding the element
- Check if block renders empty content

**Q: Two plugins want the same outlet?**
- Both should only `registerBlock()` (in pre-initializers)
- Theme calls `renderBlocks()` to compose blocks from both

**Q: Can I change layouts after boot?**
- No. Use conditions for dynamic visibility
- Use outlet args for dynamic data

---

## Testing API

```javascript
import { ... } from "discourse/tests/helpers/block-testing";
```

### Block Registration

- `withTestBlockRegistration(callback)` — Temporarily unfreeze for registration
- `registerBlock(BlockClass)` — Register a block class
- `registerBlockFactory(name, asyncFn)` — Register a lazy-loading factory
- `freezeBlockRegistry()` — Manually freeze the registry

### Block Queries

- `hasBlock(name)` — Check if block is registered
- `getBlockEntry(name)` — Get registry entry
- `isBlockRegistryFrozen()` — Check frozen state
- `resolveBlock(ref)` — Async resolve block reference

### Condition Registration

- `withTestConditionRegistration(callback)` — Temporarily unfreeze for registration
- `registerConditionType(ConditionClass)` — Register a condition type
- `freezeConditionTypeRegistry()` — Freeze condition registry

### Condition Queries

- `hasConditionType(type)` — Check if condition type is registered
- `validateConditions(spec, types)` — Validate condition specification

### Reset Utilities

- `resetBlockRegistryForTesting()` — Reset all registries to initial state
- `setTestSourceIdentifier(id)` — Override source identifier for testing

---

## Glossary

| Term | Definition |
|------|------------|
| **Block Schema** | Options passed to `@block()` that define a block's interface: name, args, constraints, outlet restrictions |
| **Block Entry** | Object in a layout specifying: block class, args, conditions, children |
| **Outlet Layout** | Array of block entries passed to `renderBlocks()` |
| **Container Block** | Block that can hold child blocks (`container: true`) |
| **Condition** | Declarative rule determining block visibility |
| **Outlet** | Designated UI location for blocks (`<BlockOutlet @name="...">`) |
| **Outlet Args** | Data passed from template to blocks via `@outletArgs` |
| **Ghost Block** | Debug placeholder showing where hidden blocks would render |
| **Factory Function** | Function returning Promise to block component for lazy loading |
| **Registry Freeze** | Point when registries become immutable (after `freeze-block-registry`) |
| **Namespace** | Prefix identifying block source (`plugin-name:` or `theme:theme-name:`) |
| **Preprocessing Pipeline** | Internal process transforming layout to renderable components |
| **Evaluation Context** | Data available to conditions: outlet args, outlet name |
