import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import devToolsState from "discourse/static/dev-tools/state";

const SESSION_STORAGE_KEY = "discourse__dev_tools_state";

function persisted() {
  return JSON.parse(window.sessionStorage.getItem(SESSION_STORAGE_KEY));
}

module("Unit | Lib | dev-tools | state", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    devToolsState.blockDebug = false;
    window.sessionStorage.removeItem(SESSION_STORAGE_KEY);
  });

  test("the singleton rejects new properties", function (assert) {
    assert.throws(
      () => {
        "use strict";
        devToolsState.somethingNew = true;
      },
      /extensible|extend/i,
      "a tool cannot store state by assigning a property"
    );
  });

  test("stores and reads a value for a tool", function (assert) {
    devToolsState.setFlag("my-tool", "enabled", true);

    assert.true(devToolsState.getFlag("my-tool", "enabled"));
  });

  test("returns undefined for values that were never set", function (assert) {
    assert.strictEqual(
      devToolsState.getFlag("absent-tool", "enabled"),
      undefined
    );
    assert.strictEqual(
      devToolsState.getFlag("my-tool", "absent-key"),
      undefined
    );
  });

  test("keeps tools' values separate", function (assert) {
    devToolsState.setFlag("tool-a", "enabled", true);
    devToolsState.setFlag("tool-b", "enabled", false);

    assert.true(devToolsState.getFlag("tool-a", "enabled"));
    assert.false(devToolsState.getFlag("tool-b", "enabled"));
  });

  test("persists values alongside the existing state", function (assert) {
    devToolsState.blockDebug = true;
    devToolsState.setFlag("my-tool", "enabled", true);

    // Asserting on this tool's own entry rather than the whole object: the
    // state is a module singleton, so values stored by earlier tests are still
    // present.
    assert.deepEqual(
      persisted().flags["my-tool"],
      { enabled: true },
      "the tool's value is written under its own key"
    );
    assert.true(
      persisted().blockDebug,
      "the built-in values are still written"
    );
  });
});
