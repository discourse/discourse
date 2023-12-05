# discourse-plugin

This package contains the public API for a v2 plugin.

In the v2 architecture, plugins are well-behaved NPM packages, which means they
can only import from packages they depend on, declared as either `dependencies`
or `peerDependencies`.

This package is the official way to expose discourse's functionalities to these
v2 plugins. They are expected to have a `peerDependencies` to this package so
that they can consume its `exported` (in `package.json`) modules, which is a
curated subset of the internal discourse code that is meant to be well-defined
and stable.

An alternative design would be to have `discourse` itself as a peer dependency
to the plugins. It can probably work if we carefully control the importable
public API via its `exports` map, but separating the public API into a separate
package makes that distinction clearer and more deliberate.

## Breaking Cycles

In an ideal world, we would start building out the underlying functionalities
in a `discourse-core` package, and both this package and `discourse` would
consume that common core. This constitutes a clear non-circular dependency
relationship between the packages.

However, since we didn't start there, we will end up finding ourselves in that
circular dependency cycle – `discourse` depends on this package (so that it can
satisfies the plugins' `peerDependencies`), but the purpose of this package is
to wrap or re-export discourse's own code, so this package finds itself needing
to import from `discourse`, but couldn't. To break that cycle, we can use the
`externals` feature of v2 addons (in `package.json`, under `ember-addon`) to
allow certain modules to be linked up in the discourse build.

## Current Status

The current state of this package is that its content isn't very deliberately
curated. It is just a whatever is needed to make porting the two demo addon
work, and provides enough of a demonstration on how we may want to curate these
APIs and/or wrap things to expose only the bits we truly want to.

Note that as it stands, v2 plugins also have full access to any of Ember's
public API, specifically the [standard ember packages](https://github.com/embroider-build/embroider/blob/ba9fd29a52f7d4791a859a5add40fd394cc9c51c/packages/shared-internals/src/ember-standard-modules.ts),
so they can, for example, import from `@glimmer/component`. This is something
we can and should revisit – the alternative would be to indirect/re-export all
public APIs from here.

## API

### helpers

Since v2 plugins exclusively uses `.gjs` for rendering, and "helpers" are
typically just plain functions, these are just a bunch of functions that we
(re-)export. We could conceivably merge this with `utils` or something more
general purpose, but at least for the time being, we retained the name
`helpers` for familiarity.

### routing

The main export here is the `Route` class (under `routing/route`).

This is a "route components" that combines the traditional equivalent of the
route (data loading – `model` hook), the controller (the "backing class") and
the route template. Rendering is handled by placing a `<template>` tag on the
class body, and it has access to the `this` instance just as expected.

It has component semantics in that it will be torn down when the route exits,
unlike the traditional routes/controllers that are long-lived. This means that
`registerDestructor()` works correctly in these route components, and stateful
modifiers/helpers/resources are cleaned up as you would expect.

It is based on the barebones base class from [ember-polaris-routing](https://github.com/chancancode/ember-polaris-service/tree/routing/ember-polaris-routing)
with a [custom API](./src/routing/route.js) that is intended to feel familiar
to the existing API but without the quirks.

The expected usage is to override the `async load()` hook, which is the direct
equivalent of the `model` hook and mostly works the same way.

The reason it was renamed is because `this.model` gives you access to the data
_returned by the load hook_, once the model is resolved (an alternative design
would to keep the `model` hook but call this field `data` or something; either
way you would have to resolve the naming conflict between "the function that
gives you the thing" vs "the thing").

The params are not passed into the `load` hook as arguments, but instead
available via `this.params`, which is accessible all throughout the class,
including in templates. It is also tracked, so it works the same as `this.args`
in other components.

You can introspect the state of the loading operation with `this.isLoading`,
etc, which are also fully reactive/tracked, so using them in the template gives
you the ability to write "loading templates".

Because the routes are loaded eagerly with the initial bundle, it is probably
best practice to treat the route component as the place where data-fetching
happens and the loading template, where the main rendering logic (and thus all
its dependencies) are placed in a separate component that is acquired via an
`import()` in the `load` hook. That way, the bulk of the code needed for the
route will only be loaded when the route is entered.

### services

There are two distinct things in here.

First, we re-export [ember-polaris-service](https://github.com/chancancode/ember-polaris-service),
which serves as the main API for v2 plugins to define and inject services.

The `ember-polaris-service` design means that services defined by plugins are
by default private to themselves, unless they explicitly chose to export them.
This means one plugin cannot reach into the private internals of another plugin
inappropriately and we won't have accidental naming conflicts.

Second, we re-export some sanctioned services from discourse that are intended
for plugin use. We may also want to wrap these services to hide any internal
states and APIs.

### utils

These are additional things like `ajax` and `I18n` that doesn't have a good
home. Again, the distinction with helpers are blurry, and we may be better off
finding a different/more functional grouping of things.
