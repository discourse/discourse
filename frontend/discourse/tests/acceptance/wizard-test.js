import {
  click,
  currentRouteName,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

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

acceptance("Wizard - dropdown field", function (needs) {
  let savedFields;

  needs.user();
  needs.hooks.beforeEach(() => (savedFields = null));
  needs.pretender((server, helper) => {
    server.get("/wizard.json", () => {
      return helper.response({
        wizard: {
          start: "styling",
          completed: false,
          steps: [
            {
              id: "styling",
              title: "Styling",
              index: 0,
              fields: [
                {
                  id: "site_style",
                  type: "dropdown",
                  label: "Style",
                  value: "plain",
                  choices: [
                    { id: "plain", label: "Plain" },
                    { id: "fancy", label: "Fancy" },
                  ],
                },
              ],
            },
          ],
        },
      });
    });

    server.put("/wizard/steps/styling", (request) => {
      savedFields = helper.parsePostData(request.requestBody).fields;
      return helper.response({});
    });
  });

  test("saves the chosen dropdown value with the step", async function (assert) {
    await visit("/wizard");

    const dropdown = selectKit(".wizard-container__dropdown");
    await dropdown.expand();
    await dropdown.selectRowByValue("fancy");

    assert.strictEqual(
      dropdown.header().value(),
      "fancy",
      "shows the chosen value"
    );

    await click(".wizard-container__button.jump-in");

    assert.deepEqual(
      savedFields,
      { site_style: "fancy" },
      "saves the chosen value with the step"
    );
  });
});
