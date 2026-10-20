---
title: Using Transformers to customize client-side values and behavior
short_title: Transformers
id: client-side-transformers
---

Discourse core includes a number of "transformer" hooks which can be used to customize client behavior. These fall into two categories:

- **Value Transformers** take an output from Discourse core, and optionally modify it, or replace it with something else

- **Behavior Transformers** can replace a particular piece of logic in Discourse core, and optionally call the original implementation.

Each transformer hook is referenced by a name, and multiple plugins/themes can register transformers against the same hook.

## Value Transformers

Value transformers can be registered using `api.registerValueTransformer`:

> ### `registerValueTransformer` => `boolean`
>
> | Param             | Type                         | Description                                |
> | ----------------- | ---------------------------- | ------------------------------------------ |
> | `transformerName` | `string`                     | the name of the transformer                |
> | `valueCallback`   | `function({value, context})` | callback to be used to transform the value |

The `valueCallback` will be passed two named arguments: the original value, and a context object. It should return the transformed value. Or, if no transformation is required, it should return the original value.

Callbacks can access the provided context for the current transformer hook, or they can reference other data sources. Many value transformers are executed in autotracking contexts, which means that referencing reactive state will cause the transformer to be automatically re-evaluated when that state changes.

For example, to modify the link URL of the logo on small screen devices:

```js
api.registerValueTransformer("home-logo-href", ({ value, context }) => {
  const capabilities = api.container.lookup("service:capabilities");
  if (!capabilities.viewport.sm) {
    // viewport narrower than the `sm` breakpoint
    return "/latest";
  } else {
    return value;
  }
});
```

## Behavior Transformers

Behavior transformers are similar, but instead of receiving and returning a value, they wrap some original behavior, and can optionally call the original implementation.

> ### `registerBehaviorTransformer` => `boolean`
>
> | Param              | Type                        | Description                                               |
> | ------------------ | --------------------------- | --------------------------------------------------------- |
> | `transformerName`  | `string`                    | the name of the transformer                               |
> | `behaviorCallback` | `function({next, context})` | callback to be used to transform or override the behavior |

The `behaviorCallback` is passed two named arguments. `next` is a function which can optionally be called to run the original behavior. `context` contains extra information which may be useful.

For example, if you wanted to limit infinite loading to 100 topics:

```js
api.registerBehaviorTransformer(
  "discovery-topic-list-load-more",
  ({ next, context }) => {
    const topicList = context.model;
    if (topicList.topics.length > 100) {
      alert("Not loading any more");
    } else {
      next();
    }
  }
);
```

## Multiple registered transformers

If multiple transformers are registered against a single name, then they will be run in order of registration. The input to valueTransformers will be the value returned by the previous transformer. The `next()` function passed to behaviorTransformers will call the remaining transformers in the chain.

## Finding Transformers

All core transformer names are listed in [lib/registry/transformers.ts](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/registry/transformers.ts), which also declares the value, context, and return types of the hooks that have been typed. For the others, search for the name in the core codebase to find where it's applied, its context and value, and the expected return type. Editors that understand TypeScript complete hook names when you call `applyValueTransformer`, `api.registerValueTransformer`, and their behavior counterparts, including in plain JavaScript files.

## Introducing new Transformers

To introduce new transformers, the name first needs to be added to the registry. In core, add it to [lib/registry/transformers.ts](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/registry/transformers.ts).

To introduce a new transformer via a theme or plugin, create a `pre-initializer` and register the name via the relevant API:

```js
// .../discourse/pre-initializers/my-transformer.js
export default {
  before: "freeze-valid-transformers",
  initialize() {
    withPluginApi((api) => {
      api.addValueTransformerName("my-value-transform");
      api.addBehaviorTransformerName("my-behavior-transform");
    });
  },
};
```

To apply the transformer to some value or behavior, import the associated `apply` function and use it anywhere in your code:

```js
import {
  applyValueTransformer,
  applyBehaviorTransformer,
} from "discourse/lib/transformer";

const context = { bestForumSoftware: "Discourse" };

// Value Transformer
const originalValue = "Hello";
const transformedValue = applyValueTransformer(
  "my-value-transform",
  originalValue,
  context
);

// Behavior Transformer
applyBehaviorTransformer(
  "my-behavior-transformer",
  () => {
    alert("This is the core implementation");
  },
  context
);
```

## TypeScript

The transformer pipeline exports callback types from `discourse/lib/transformer`: `ValueTransformer<T, C>` returns the transformed value, `MutableValueTransformer<T, C>` mutates the value and returns `void`, and `BehaviorTransformer<R, C>` is behavior middleware. `T` is the value, `R` the behavior result, and `C` the context, which can be an interface without an index signature.

### Typed hooks

Each hook can declare its contract in a registry, keyed by name: `ValueTransformerRegistry` for value hooks and `BehaviorTransformerRegistry` for behavior hooks. Once a hook is typed, its name alone determines every signature:

- `applyValueTransformer`, `applyMutableValueTransformer`, and `applyBehaviorTransformer` check the default value or callback and the context against the entry, and return the entry's type.
- `api.registerValueTransformer` and `api.registerBehaviorTransformer` type the callback's `value`, `context`, and return from the entry, so inline callbacks need no annotations.
- A hook applied with `applyMutableValueTransformer` must be registered with `mutable: true`, and the reverse.

Use `ValueTransformerFor<"name">` or `BehaviorTransformerFor<"name">` to type a callback declared ahead of time:

```ts
import type { ValueTransformerFor } from "discourse/lib/transformer";

const addClass: ValueTransformerFor<"topic-list-item-class"> = ({ value }) => [
  ...value,
  "my-class",
];

api.registerValueTransformer("topic-list-item-class", addClass);
```

Core hooks without a contract yet are marked `Untyped` and keep the loose typing described below. Value entries have the shape `{ value: V; context: C | undefined; mutable: true | false }`, and behavior entries `{ result: R; context: C | undefined }`. Include `undefined` in `context` when the context is optional, or use `context: undefined` when a hook has none. Entries that don't match these shapes make the hook unusable until they are fixed.

A plugin or theme can type its own hooks by adding entries from a TypeScript file. The name still needs `api.addValueTransformerName` or `api.addBehaviorTransformerName` at runtime:

```ts
declare module "discourse/lib/transformer" {
  interface ValueTransformerRegistry {
    "my-plugin-label": {
      value: string | null;
      context: { userId: number };
      mutable: false;
    };
  }
}
```

### Untyped and unregistered hooks

`applyValueTransformer` and `applyMutableValueTransformer` infer the result type from the default value. When a hook can return a broader type than its default, widen the default rather than passing a type argument, for example `applyValueTransformer("custom-label", null as string | null)`. Explicit type arguments describe the hook name, so `applyValueTransformer<string | null>(…)` doesn't compile, and `applyValueTransformer<"custom-label">(…)` returns `unknown`. Registration and application of an untyped hook must agree on its value, context, and return types by convention, because nothing checks them against each other.

### Hook names

In TypeScript, a hook name must be a single string literal. A name held in a `string` variable, a union of names, or a template literal type is rejected, because it could hide a typed hook behind the loose signature. Calling the apply functions through `.call` or pre-binding the name with `.bind(thisArg, name)` isn't supported; call them directly, use `.bind(thisArg)`, or wrap them in a function.

### Behavior results

Behavior callbacks receive a shallow copy of the context. `next()` and `applyBehaviorTransformer` can return `void` when middleware stops the chain or calls `next()` after the queue is exhausted. Promise results pass through unchanged, and async middleware that awaits `next()` resolves to the awaited result or `undefined`; `BehaviorTransformerResult<R>` describes the full result type. A typed hook whose result is `void` accepts middleware with any return value, since that value is ignored.
