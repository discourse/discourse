import {
  click,
  fillIn,
  find,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import { formatShortcut } from "discourse/lib/shortcut-format";
import { capabilities } from "discourse/services/capabilities";
import postFixtures from "discourse/tests/fixtures/post";
import {
  acceptance,
  metaModifier,
  selectText,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Fast Edit", function (needs) {
  needs.user();
  needs.settings({ enable_fast_edit: true });
  needs.pretender((server, helper) => {
    server.get("/posts/419", () => {
      return helper.response(cloneJSON(postFixtures["/posts/398"]));
    });
  });

  test("Fast edit button works", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const textNode = find("#post_1 .cooked p").childNodes[0];

    await selectText(textNode, 9);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();
    assert
      .dom("#fast-edit-input")
      .hasValue("Any plans", "contains selected text");

    await fillIn("#fast-edit-input", "My edit");
    await click(".save-fast-edit");

    assert.dom("#fast-edit-input").doesNotExist();
  });

  test("Works with keyboard shortcut", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const textNode = find("#post_1 .cooked p").childNodes[0];

    await selectText(textNode, 9);

    assert.dom(".quote-button").exists();

    await triggerKeyEvent(document, "keypress", "E");

    assert.dom("#fast-edit-input").exists();
    assert
      .dom("#fast-edit-input")
      .hasValue("Any plans", "contains selected text");

    // Saving
    await fillIn("#fast-edit-input", "My edit");
    await triggerKeyEvent("#fast-edit-input", "keydown", "Enter", metaModifier);

    assert.dom("#fast-edit-input").doesNotExist();

    // Closing
    await selectText(textNode, 9);

    assert.dom(".quote-button").exists();

    await triggerKeyEvent(document, "keypress", "E");

    assert.dom("#fast-edit-input").exists();

    await triggerKeyEvent("#fast-edit-input", "keydown", "Escape");
    assert.dom("#fast-edit-input").doesNotExist();
  });

  test("Opens full composer for multi-line selection", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const textNode = find("#post_2 .cooked");

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").doesNotExist();
    assert.dom(".d-editor-input").exists();
  });

  test("Opens full composer when selection has typographic characters", async function (assert) {
    await visit("/t/internationalization-localization/280");

    find("#post_2 .cooked").append(`That’s what she said!`);
    const textNode = find("#post_2 .cooked").childNodes[3];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").doesNotExist();
    assert.dom(".d-editor-input").exists();
  });

  test("Works with diacritics", async function (assert) {
    await visit("/t/internationalization-localization/280");

    find("#post_2 .cooked").append(`Je suis désolé, comment ça va?`);
    const textNode = find("#post_2 .cooked").childNodes[3];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();
  });

  test("Works with CJK ranges", async function (assert) {
    await visit("/t/internationalization-localization/280");

    find("#post_2 .cooked").append(`这是一个测试`);
    const textNode = find("#post_2 .cooked").childNodes[3];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();
  });

  test("Works with emoji", async function (assert) {
    await visit("/t/internationalization-localization/280");

    find("#post_2 .cooked").append(`This is great 👍`);
    const textNode = find("#post_2 .cooked").childNodes[3];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();
  });

  test("gate: the save button names the shortcut only with a keyboard", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await selectText("#post_1 .cooked p");
    await click(".quote-button .quote-edit-label");

    assert.dom(".save-fast-edit").hasAttribute(
      "title",
      i18n("composer.submit_shortcut_title", {
        shortcut: formatShortcut("mod+enter").label,
      })
    );

    sinon.stub(capabilities, "hasKeyboard").get(() => false);
    await visit("/");
    await visit("/t/internationalization-localization/280");
    await selectText("#post_1 .cooked p");
    await click(".quote-button .quote-edit-label");

    assert
      .dom(".save-fast-edit")
      .doesNotHaveAttribute("title")
      .doesNotHaveAttribute("aria-keyshortcuts");
  });
});
