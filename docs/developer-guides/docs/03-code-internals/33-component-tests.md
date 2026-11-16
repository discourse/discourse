---
title: Write component tests for Discourse
short_title: Component tests
id: component-tests
---

<div data-theme-toc="true"> </div>

Component tests render a single component in isolation and assert on the DOM it produces. They are faster and more focused than acceptance tests, which boot the whole application and visit a route. To run them, see [Run test suites](05-run-test-suites.md).

## Where tests live

| Code under test | Test location                                        |
| --------------- | ---------------------------------------------------- |
| Core            | `frontend/discourse/tests/integration/components/**` |
| Core `ui-kit`   | `frontend/discourse/tests/integration/ui-kit/**`     |
| Plugin          | `plugins/<name>/test/javascripts/integration/**`     |

Name the file after the component with a `-test.gjs` suffix. The `.gjs` format lets the test import the component and invoke it in an inline `<template>`, the same way production code does.

## A first test

```gjs
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";

module("Integration | Component | DPageSubheader", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the title", async function (assert) {
    await render(
      <template><DPageSubheader @titleLabel="Settings" /></template>
    );

    assert
      .dom(".d-page-subheader__title")
      .hasText("Settings", "shows @titleLabel");
  });
});
```

- Import `setupRenderingTest` from `discourse/tests/helpers/component-test`, not from `ember-qunit`. The Discourse wrapper also sets up `this.siteSettings`, `this.site` and a logged-in `this.currentUser`. Pass `{ anonymous: true }` as the second argument to render as a guest.
- The module title ends with the component's invocation name in PascalCase (`DPageSubheader`, not `d-page-subheader`).
- Assert with [qunit-dom](https://github.com/mainmatter/qunit-dom/blob/master/API.md) (`assert.dom(...)`), and give every assertion a description so a failure says what broke.
- Plugin components are imported from `discourse/plugins/<name>/discourse/components/...`.

## Interacting with the component

The helpers in `@ember/test-helpers` (`click`, `fillIn`, `triggerKeyEvent`, ...) dispatch real DOM events and wait for the resulting render. Always `await` them.

To check what the component reports back, pass a function that records its calls with `assert.step`:

```gjs
import { click, render } from "@ember/test-helpers";
import DButton from "discourse/ui-kit/d-button";

test("calls @action on click", async function (assert) {
  const onClick = () => assert.step("clicked");

  await render(
    <template><DButton @action={{onClick}} @translatedLabel="Save" /></template>
  );
  await click(".btn");

  assert.verifySteps(["clicked"], "calls @action once");
});
```

## Changing arguments after render

To test how a component reacts when its arguments change, hold the value in a standalone `tracked()` from `@glimmer/tracking`. Pass its `.value` to the component, then assign a new `.value`:

```gjs
import { tracked } from "@glimmer/tracking";
import { render, rerender } from "@ember/test-helpers";

test("follows @titleLabel", async function (assert) {
  const title = tracked("First");

  await render(
    <template><DPageSubheader @titleLabel={{title.value}} /></template>
  );

  title.value = "Second";
  await rerender();

  assert
    .dom(".d-page-subheader__title")
    .hasText("Second", "shows the new title");
});
```

- Use one `tracked()` per argument, instead of `this.set(...)` on the test context or a test-only class with `@tracked` fields. Values that don't change can be local constants, or native assignments to the test context (`this.title = "a"`) before render.
- When the component writes a value back through a callback, such as `@onChange`, the callback assigns the tracked value: `const onChange = (newValue) => (value.value = newValue)`. A value a callback only records for the test to assert on is a plain local `let`.
- When the test changes properties of an object it passes in, such as a model, make that object a `trackedObject` (from `@ember/reactive/collections`) and assign its properties instead.
- `await rerender()` before the next assertion or interaction: unlike `this.set`, a tracked write does not re-render synchronously. Use `await settled()` instead when the change starts async work, such as a request.
- Start with the first value the test asserts. To start empty, use `tracked(undefined)`: a bare `tracked()` returns a decorator, and so does a single plain object whose keys are all option names (`value`, `initializer`, `equals`, `description`). Passing options as well forces the value form: `tracked({}, {})`.
- Assigning a value that is `Object.is`-equal to the current one does not re-render. Pass `{ equals: () => false }` as the second argument if a test relies on that.

## Stubbing requests

A default [Pretender](https://github.com/pretenderjs/pretender) server answers common endpoints. Add or override a route inside the test:

```gjs
import pretender, { response } from "discourse/tests/helpers/create-pretender";

test("shows the loaded items", async function (assert) {
  pretender.get("/admin/things.json", () => response({ things: [] }));
  // render and assert...
});
```

`response(body)` replies with a 200; `response(status, body)` sets the status. Stub the network boundary like this rather than stubbing the component's own collaborators.
