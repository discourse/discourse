import { currentRouteName, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Wizard", function (needs) {
  needs.user();

  test("Wizard starts", async function (assert) {
    await visit("/wizard");
    assert.dom(".wizard-container").exists();
    assert
      .dom(".d-header-wrap")
      .doesNotExist("header is not rendered on wizard pages");
    assert.strictEqual(currentRouteName(), "wizard.step");
  });

  test("custom keyboard shortcuts are disabled while the wizard is active", async function (assert) {
    let shortcutTriggered = false;
    withPluginApi((api) => {
      api.addKeyboardShortcut("]", () => (shortcutTriggered = true));
    });

    await visit("/wizard");
    await triggerKeyEvent(document, "keypress", "]".charCodeAt(0));

    assert.false(shortcutTriggered, "the custom shortcut does not run");

    await visit("/");
    await triggerKeyEvent(document, "keypress", "]".charCodeAt(0));

    assert.true(
      shortcutTriggered,
      "the custom shortcut runs outside the wizard"
    );
  });
});
