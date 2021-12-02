import {
  acceptance,
  exists,
  query,
  selectText,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import postFixtures from "discourse/tests/fixtures/post";
import { cloneJSON } from "discourse-common/lib/object";

acceptance("Fast Edit", function (needs) {
  needs.user();
  needs.settings({
    enable_fast_edit: true,
  });
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

    assert.ok(exists("#fast-edit-input"), "fast editor is open");
    assert.strictEqual(
      query("#fast-edit-input").value,
      "Any plans",
      "contains selected text"
    );

    await fillIn("#fast-edit-input", "My edit");
    await click(".save-fast-edit");

    assert.notOk(exists("#fast-edit-input"), "fast editor is closed");
  });

  test("Works with keyboard shortcut", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const textNode = query("#post_1 .cooked p").childNodes[0];

    await selectText(textNode, 9);
    await triggerKeyEvent(document, "keypress", "e".charCodeAt(0));

    assert.ok(exists("#fast-edit-input"), "fast editor is open");
    assert.strictEqual(
      query("#fast-edit-input").value,
      "Any plans",
      "contains selected text"
    );

    await fillIn("#fast-edit-input", "My edit");
    await click(".save-fast-edit");

    assert.notOk(exists("#fast-edit-input"), "fast editor is closed");
  });

  test("Opens full composer for multi-line selection", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const textNode = query("#post_2 .cooked");

    await selectText(textNode);
    await click(".quote-button .quote-edit-label");

    assert.notOk(exists("#fast-edit-input"), "fast editor is not open");
    assert.ok(exists(".d-editor-input"), "the composer is open");
  });
});
