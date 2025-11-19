import { getOwner } from "@ember/owner";
import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Plugin Keyboard Shortcuts - Logged In", function (needs) {
  needs.user();

  test("a plugin can add a keyboard shortcut", async function (assert) {
    withPluginApi((api) => {
      api.addKeyboardShortcut("]", () => {
        document.querySelector("#qunit-fixture").innerHTML =
          `<div id="added-element">Test adding plugin shortcut</div>`;
      });
    });

    await visit("/t/this-is-a-test-topic/9");
    await triggerKeyEvent(document, "keypress", "]".charCodeAt(0));

    assert
      .dom("#added-element", document.body)
      .exists("the keyboard shortcut callback fires successfully");
  });
});

acceptance("Plugin Keyboard Shortcuts - Anonymous", function () {
  test("a plugin can add a keyboard shortcut with an option", async function (assert) {
    let spy = sinon.spy(
      getOwner(this).lookup("service:keyboard-shortcuts"),
      "_bindToPath"
    );
    withPluginApi((api) => {
      api.addKeyboardShortcut("]", () => {}, {
        anonymous: true,
        path: "test-path",
      });
    });

    assert.true(
      spy.calledWith("test-path", "]"),
      "bindToPath is called due to options provided"
    );
  });

  test("a plugin can add a shortcut and create a new category in the shortcut help modal", async function (assert) {
    withPluginApi((api) => {
      api.addKeyboardShortcut("meta+]", () => {}, {
        help: {
          category: "new_category",
          name: "new_category.test",
          definition: {
            keys1: ["meta", "]"],
            keys2: ["meta", "["],
            keysDelimiter: "plus",
            shortcutsDelimiter: "slash",
          },
        },
      });
    });
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));

    assert.dom(".shortcut-category-new_category").exists();
    assert.dom(".shortcut-category-new_category li").exists({ count: 1 });
  });

  test("a plugin can add a shortcut to and existing category in the shortcut help modal", async function (assert) {
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));
    const countBefore = document.querySelectorAll(
      ".shortcut-category-application li"
    ).length;

    await click(".modal-close");

    withPluginApi((api) => {
      api.addKeyboardShortcut("meta+]", () => {}, {
        help: {
          category: "application",
          name: "application.test",
          definition: {
            keys1: ["]"],
          },
        },
      });
    });

    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));
    assert
      .dom(".shortcut-category-application li")
      .exists({ count: countBefore + 1 });
  });
});
