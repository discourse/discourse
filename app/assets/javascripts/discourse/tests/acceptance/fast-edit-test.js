import {
  acceptance,
  exists,
  queryAll,
  selectText,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Fast Edit", function (needs) {
  needs.user();
  needs.settings({
    enable_fast_edit: true,
  });

  test("Fast edit button works", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const textNode = document.querySelector("#post_1 .cooked p").childNodes[0];

    await selectText(textNode, 9);
    await click(".quote-button .quote-edit-label");

    assert.ok(exists("#fast-edit-input"), "fast editor is open");
    assert.strictEqual(
      queryAll("#fast-edit-input").val(),
      "Any plans",
      "contains selected text"
    );

    await fillIn("#fast-edit-input", "My edit");
    await click(".save-fast-edit");

    assert.notOk(exists("#fast-edit-input"), "fast editor is closed");
  });

  test("Works with keyboard shortcut", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const textNode = document.querySelector("#post_1 .cooked p").childNodes[0];

    await selectText(textNode, 9);
    await triggerKeyEvent(document, "keypress", "e".charCodeAt(0));

    assert.ok(exists("#fast-edit-input"), "fast editor is open");
    assert.strictEqual(
      queryAll("#fast-edit-input").val(),
      "Any plans",
      "contains selected text"
    );

    await fillIn("#fast-edit-input", "My edit");
    await click(".save-fast-edit");

    assert.notOk(exists("#fast-edit-input"), "fast editor is closed");
  });

  test("Opens full composer for multi-line selection", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const textNode = document.querySelector("#post_1 .cooked");

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.notOk(exists("#fast-edit-input"), "fast editor is not open");
    assert.ok(exists(".d-editor-input"), "the composer is open");
  });
});
