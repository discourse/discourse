import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Composer - Hyperlink", function (needs) {
  needs.user();

  test("add a hyperlink to a reply", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:first-child button.reply");
    await fillIn(".d-editor-input", "This is a link to ");

    assert.ok(
      !exists(".insert-link.modal-body"),
      "no hyperlink modal by default"
    );

    await click(".d-editor button.link");
    assert.ok(exists(".insert-link.modal-body"), "hyperlink modal visible");

    await fillIn(".modal-body .link-url", "google.com");
    await fillIn(".modal-body .link-text", "Google");
    await click(".modal-footer button.btn-primary");

    assert.strictEqual(
      query(".d-editor-input").value,
      "This is a link to [Google](https://google.com)",
      "adds link with url and text, prepends 'https://'"
    );

    assert.ok(
      !exists(".insert-link.modal-body"),
      "modal dismissed after submitting link"
    );

    await fillIn(".d-editor-input", "Reset textarea contents.");

    await click(".d-editor button.link");
    await fillIn(".modal-body .link-url", "google.com");
    await fillIn(".modal-body .link-text", "Google");
    await click(".modal-footer button.btn-danger");

    assert.strictEqual(
      query(".d-editor-input").value,
      "Reset textarea contents.",
      "doesn’t insert anything after cancelling"
    );

    assert.ok(
      !exists(".insert-link.modal-body"),
      "modal dismissed after cancelling"
    );

    const textarea = query("#reply-control .d-editor-input");
    textarea.selectionStart = 0;
    textarea.selectionEnd = 6;
    await click(".d-editor button.link");

    await fillIn(".modal-body .link-url", "somelink.com");
    await click(".modal-footer button.btn-primary");

    assert.strictEqual(
      query(".d-editor-input").value,
      "[Reset](https://somelink.com) textarea contents.",
      "adds link to a selected text"
    );

    await fillIn(".d-editor-input", "");

    await click(".d-editor button.link");
    await fillIn(".modal-body .link-url", "http://google.com");
    await triggerKeyEvent(".modal-body .link-url", "keyup", "Space");
    assert.ok(
      !exists(".internal-link-results"),
      "does not show internal links search dropdown when inputting a url"
    );

    await fillIn(".modal-body .link-url", "local");
    await triggerKeyEvent(".modal-body .link-url", "keyup", "Space");
    assert.ok(
      exists(".internal-link-results"),
      "shows internal links search dropdown when entering keywords"
    );

    await triggerKeyEvent(".insert-link", "keydown", "ArrowDown");
    await triggerKeyEvent(".insert-link", "keydown", "Enter");

    assert.ok(
      !exists(".internal-link-results"),
      "search dropdown dismissed after selecting an internal link"
    );

    assert.ok(
      query(".link-url").value.includes("http"),
      "replaces link url field with internal link"
    );

    await triggerKeyEvent(".insert-link", "keydown", "Escape");

    assert.strictEqual(
      document.activeElement.classList.contains("d-editor-input"),
      true,
      "focus stays on composer after dismissing modal using Esc key"
    );
  });
});
