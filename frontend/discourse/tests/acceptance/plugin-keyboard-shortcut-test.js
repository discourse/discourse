import { getOwner } from "@ember/owner";
import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

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
    assert.dom(".shortcut-category-new_category tbody tr").exists({ count: 1 });
  });

  test("help modal: draws entity arrow keys as glyphs with spoken names", async function (assert) {
    withPluginApi((api) => {
      api.addKeyboardShortcut("alt+up", () => {}, {
        help: {
          category: "new_category",
          name: "new_category.test",
          definition: {
            keys1: ["alt", "&uarr;"],
            keys2: ["alt", "&darr;"],
            shortcutsDelimiter: "slash",
          },
        },
      });
    });
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));

    const cell = ".shortcut-category-new_category .shortcut-key";
    assert.dom(`${cell} .d-shortcut__key--glyph [aria-hidden]`, null).exists();
    assert
      .dom(
        `${cell} .d-shortcut:nth-of-type(1) .d-shortcut__key:last-child [aria-hidden]`
      )
      .hasText("↑");
    assert
      .dom(
        `${cell} .d-shortcut:nth-of-type(1) .d-shortcut__key:last-child .sr-only`
      )
      .hasText(i18n("shortcut_modifier_key.arrow_up"));
    assert.dom(cell).doesNotIncludeText("&uarr;");
  });

  test("help modal: draws a literal plus key", async function (assert) {
    withPluginApi((api) => {
      api.addKeyboardShortcut("shift++", () => {}, {
        help: {
          category: "new_category",
          name: "new_category.test",
          definition: { keys1: ["shift", "+"] },
        },
      });
    });
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));

    assert
      .dom(".shortcut-category-new_category .d-shortcut__key")
      .exists({ count: 2 });
    assert
      .dom(
        ".shortcut-category-new_category .d-shortcut__key:last-child [aria-hidden]"
      )
      .hasText("+");
  });

  test("help modal: breaks a newline delimiter onto two lines", async function (assert) {
    withPluginApi((api) => {
      api.addKeyboardShortcut("j", () => {}, {
        help: {
          category: "new_category",
          name: "new_category.test",
          definition: {
            keys1: ["j"],
            keys2: ["k"],
            shortcutsDelimiter: "newline",
          },
        },
      });
    });
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));

    assert
      .dom(".shortcut-category-new_category .delimiter-newline > br")
      .exists({ count: 1 });
    assert
      .dom(".shortcut-category-new_category .delimiter-newline .d-shortcut")
      .exists({ count: 2 });
  });

  test("help modal: falls back to the or delimiter for an unknown one", async function (assert) {
    withPluginApi((api) => {
      api.addKeyboardShortcut("j", () => {}, {
        help: {
          category: "new_category",
          name: "new_category.test",
          definition: {
            keys1: ["j"],
            keys2: ["k"],
            shortcutsDelimiter: "comma",
          },
        },
      });
    });
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));

    const cell = ".shortcut-category-new_category .shortcut-key";
    assert.dom(`${cell} .d-shortcut`).exists({ count: 2 });
    assert.dom(cell).doesNotIncludeText("[en.");
    assert.dom(cell).hasText(
      i18n("keyboard_shortcuts_help.shortcut_delimiter_or", {
        shortcut1: "J",
        shortcut2: "K",
      })
    );
  });

  test("a plugin can add a shortcut to and existing category in the shortcut help modal", async function (assert) {
    await visit("/");
    await triggerKeyEvent(document, "keypress", "?".charCodeAt(0));
    const countBefore = document.querySelectorAll(
      ".shortcut-category-application tbody tr"
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
      .dom(".shortcut-category-application tbody tr")
      .exists({ count: countBefore + 1 });
  });
});
