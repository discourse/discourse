import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import postFixtures from "discourse/tests/fixtures/post";
import {
  acceptance,
  metaModifier,
  query,
  selectText,
} from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";

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

    const textNode = query("#post_1 .cooked p").childNodes[0];

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

    const textNode = query("#post_1 .cooked p").childNodes[0];

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

    const textNode = query("#post_2 .cooked");

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").doesNotExist();
    assert.dom(".d-editor-input").exists();
  });

  test("Opens full composer when selection has typographic characters", async function (assert) {
    await visit("/t/internationalization-localization/280");

    query("#post_2 .cooked").append(`That’s what she said!`);
    const textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").doesNotExist();
    assert.dom(".d-editor-input").exists();
  });

  test("Works with diacritics", async function (assert) {
    await visit("/t/internationalization-localization/280");

    query("#post_2 .cooked").append(`Je suis désolé, comment ça va?`);
    const textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();
  });

  test("Works with CJK ranges", async function (assert) {
    await visit("/t/internationalization-localization/280");

    query("#post_2 .cooked").append(`这是一个测试`);
    const textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();
  });

  test("Works with emoji", async function (assert) {
    await visit("/t/internationalization-localization/280");

    query("#post_2 .cooked").append(`This is great 👍`);
    const textNode = query("#post_2 .cooked").childNodes[2];

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.dom("#fast-edit-input").exists();
  });
});
