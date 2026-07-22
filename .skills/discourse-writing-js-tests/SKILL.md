---
name: discourse-writing-js-tests
description: Write and structure JavaScript/QUnit tests for Discourse core, plugins, and themes. Use when creating or modifying unit tests (lib/utility/service/model), component rendering tests, integration tests, or acceptance tests. Covers module naming, setupTest/setupRenderingTest/setupApplicationTest, fixtures, the qunit-helpers toolbox, pretender, and qunit-dom assertions.
---

# Writing JavaScript (QUnit) Tests

Discourse uses [QUnit](https://qunitjs.com/) with `ember-qunit` and
[`@ember/test-helpers`](https://github.com/emberjs/ember-test-helpers). Assertions use
[`qunit-dom`](https://github.com/mainmatter/qunit-dom/blob/master/API.md) (`assert.dom(...)`).

## Testing Principles

- **Test behavior, not implementation** — assert on rendered output, DOM state, and public
  return values, not internal component state or private methods.
- **One concept per `test`** — each `test()` verifies one behavior for clear failure diagnosis.
- **Prefer `assert.dom(...)`** over manual DOM querying. It produces better failure messages
  and waits-free, synchronous DOM reads. See the [qunit-dom API](https://github.com/mainmatter/qunit-dom/blob/master/API.md).
  When you need the element(s) themselves — for an interaction or a computed value — use
  `find()` / `findAll()` from `@ember/test-helpers` (scoped to the test container), not
  `document.querySelector` or the deprecated `queryAll()`.
- **Always `await` interactions** — `render`, `click`, `fillIn`, `visit`, `settled`, etc. are
  async. Forgetting `await` causes flaky tests.
- **Always pass a description** as the last argument to assertions — it documents intent and
  pinpoints failures: `assert.dom(".foo").exists("the widget renders")`.
- **Keep tests independent** — global state is reset between tests by `testCleanup` (see
  `qunit-helpers.js`); don't rely on order or leak registrations.
- **Don't over-stub** — stub network boundaries via pretender, not internal collaborators.

## File locations & naming

| Type | Location | Setup helper |
| --- | --- | --- |
| Unit (lib/utility/service/model) | `frontend/discourse/tests/unit/**` | `setupTest` |
| Component rendering | `frontend/discourse/tests/integration/components/**` | `setupRenderingTest` |
| Other integration | `frontend/discourse/tests/integration/**` | `setupRenderingTest`/`setupTest` |
| Acceptance (full app) | `frontend/discourse/tests/acceptance/**` | `acceptance(...)` |
| Plugin tests | `plugins/<name>/test/javascripts/**` | same helpers |

Test files end in `-test.js` or `-test.gjs` (use `.gjs` when the test renders a component template).

### Module naming convention

The `module(...)` title is a `|`-separated hierarchy. The **last** segment is the subject.
For **components**, the subject must be the modern **PascalCase** invocation name — matching
how Ember invokes the component (`<PollInfo />`), not the kebab-case filename:

```js
// GOOD — component subject is PascalCase
module("Integration | Component | PollInfo", function (hooks) { ... });
module("Component | ChatChannelCard", function (hooks) { ... });   // plugins

// nested components: each path segment is its own PascalCase pipe segment
module("Integration | Component | SelectKit | ComboBox", ...);     // select-kit/combo-box
module("Integration | Component | Post | Menu | PostUsersMenu", ...);

// BAD — kebab-case or slash paths for components
module("Integration | Component | poll-info", ...);
module("Integration | Component | select-kit/combo-box", ...);
```

Non-component subjects (`Lib`, `Utility`, `Service`, `Model`, `Controller`, `Route`) stay
**kebab-case**, matching their filenames:

```js
module("Unit | Lib | singleton", ...);
module("Unit | Utility | user-search", ...);
module("Unit | Service | site-settings", ...);
module("Unit | Model | topic", ...);
```

Common prefixes: `Unit | <Kind> | <subject>`, `Integration | Component | <PascalName>`,
acceptance tests are auto-prefixed with `Acceptance: ` by the `acceptance()` helper.

## Unit tests (`setupTest`)

For libs, utilities, services, models — no rendering.

```js
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import singleton from "discourse/lib/singleton";

module("Unit | Lib | singleton", function (hooks) {
  setupTest(hooks);

  test("current returns a memoized instance", function (assert) {
    const current = SomeModel.current();
    assert.strictEqual(current, SomeModel.current());
  });
});
```

Look services/objects up from the owner: `getOwner(this).lookup("service:site-settings")`.

## Component rendering tests (`setupRenderingTest`)

Import `setupRenderingTest` from **`discourse/tests/helpers/component-test`** (the Discourse
wrapper), NOT directly from `ember-qunit`. The wrapper also sets `this.siteSettings`,
`this.site`, `this.session`, and a logged-in `this.currentUser` for you.

```js
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BookmarkIcon from "discourse/components/bookmark-icon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | BookmarkIcon", function (hooks) {
  setupRenderingTest(hooks);

  test("with reminder", async function (assert) {
    const store = this.owner.lookup("service:store");
    const bookmark = store.createRecord("bookmark", { name: "some name" });

    await render(<template><BookmarkIcon @bookmark={{bookmark}} /></template>);

    assert.dom(".d-icon-discourse-bookmark-clock").exists();
    assert.dom(".svg-icon-title").hasAttribute("title", i18n("bookmarks.created"));
  });
});
```

- Prefer **`.gjs`** with inline `<template>` so you can import and invoke the real component.
- Options: `setupRenderingTest(hooks, { anonymous: true })` for an anonymous user;
  `{ stubRouter: true }` to stub `service:router`.
- Interact with `@ember/test-helpers`: `click`, `fillIn`, `triggerKeyEvent`, `settled`; query
  the rendered DOM with `find` (first match) / `findAll` (all matches).
- For select-kit and FormKit widgets, use `discourse/tests/helpers/select-kit-helper` and
  `discourse/tests/helpers/form-kit-helper` rather than poking the DOM directly.

## Acceptance tests (`acceptance`)

Full-application tests that `visit()` routes. Use the `acceptance()` helper from
`qunit-helpers` — it wires up `setupApplicationTest`, the default pretender, site, settings,
and per-test cleanup. Configure the scenario through the `needs` argument.

```js
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Topic Notifications button", function (needs) {
  needs.user();                       // logged-in user (optionally pass overrides)
  needs.settings({ enable_foo: true });
  needs.site({ categories: [...] });
  needs.mobileView();
  needs.pretender((server, helper) => {
    server.post("/t/280/notifications", () => helper.response({}));
  });

  test("updates the notification level", async function (assert) {
    await visit("/t/internationalization-localization/280");
    assert.dom(".topic-notifications-button").exists();
  });
});
```

`needs.*` options: `user(overrides)`, `pretender(fn)`, `site(changes)`, `settings(changes)`,
`mobileView()`. The active QUnit `hooks` are available as `needs.hooks`.

## Network stubbing (pretender)

Discourse ships a large default [Pretender](https://github.com/pretenderjs/pretender) server
(`frontend/discourse/tests/helpers/create-pretender.js`) that answers common endpoints. Add or
override routes with `needs.pretender(...)` (acceptance) or `pretender`/`applyPretender`
patterns for other types. The `helper.response(body)` / `helper.response(statusCode, body)`
builders shape responses.

## Fixtures

Canned API payloads live in `frontend/discourse/tests/fixtures/**` and back the default
pretender. Import a fixture to seed models or assertions instead of hand-building JSON:

```js
import sessionFixtures from "discourse/tests/fixtures/session-fixtures";
import siteFixtures from "discourse/tests/fixtures/site-fixtures";
```

`currentUser()` (from `qunit-helpers`) builds a `User` from the session fixture.

## The `qunit-helpers` toolbox

`frontend/discourse/tests/helpers/qunit-helpers.js` exports broadly useful helpers:

- **Users/session**: `acceptance`, `currentUser()`, `logIn(owner)`, `loggedInUser()`,
  `updateCurrentUser(props)`, `resetSite(extras)`.
- **MessageBus**: `publishToMessageBus(channel, ...args)` — drive realtime updates, then assert.
- **Time**: `fakeTime(timeString, tz, advance)` and `withFrozenTime(timeString, tz, cb)` (sinon
  fake timers). Remember to restore (`withFrozenTime` does it for you).
- **Input simulation**: `createFile(name, type)`, `paste(selector, text)`,
  `selectText(selector)`, `simulateKey(el, key)` / `simulateKeys(el, keys)`, `metaModifier`.
- **Conditional tests**: `conditionalTest`, `chromeTest`, `firefoxTest`.
- **DOM lookup helpers**: `query()`, `exists()`, `count()`, `visible()`, `invisible()`,
  `fixture()`. **Prefer `assert.dom(...)` for assertions and `find()` / `findAll()` for
  elements in new tests** — reach for these only when matching existing style.
- **Deprecated, do not use**: `queryAll()` — use `findAll()` or `assert.dom(...)` instead;
  `discourseModule` — use QUnit's `module` instead.

## Custom assertions

Beyond [qunit-dom](https://github.com/mainmatter/qunit-dom/blob/master/API.md)'s `assert.dom`:

- `assert.present(value, msg)` / `assert.blank(value, msg)` — Ember `isEmpty` checks.
- `assert.containsInstance(collection, klass, msg)`.
- Domain assertions registered at import time: `assert.form()` (FormKit, see
  `form-kit-assertions.js`), `assert.dselect()` (`d-select-assertions.js`),
  `assert.notificationsTracking()` (`notifications-tracking-assertions.js`).

## Running tests

```sh
bin/qunit --help                       # full options
bin/qunit path/to/some-test.gjs        # one file
bin/qunit path/to/integration/components  # a directory
bin/qunit --filter "BookmarkIcon"      # literal, case-insensitive substring of "module: test name"
bin/qunit --filter-regex "Foo|Bar"     # JavaScript regex over "module: test name" (use for alternation)
bin/qunit --target chat                # a specific plugin
```

`--filter` matches a literal substring, so `|` and other regex characters are treated
literally; use `--filter-regex` when you need alternation or other patterns.

Requires a running Rails server (or pass `--standalone` to spin up an isolated one).

## Before committing

Always lint changed test files:

```sh
bin/lint --fix --recent
```
