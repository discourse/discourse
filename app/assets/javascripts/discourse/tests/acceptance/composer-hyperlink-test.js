import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Composer - Hyperlink", function (needs) {
  needs.user();

  test("add a hyperlink to a reply", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:first-child button.reply");
    await fillIn(".d-editor-input", "This is a link to ");

    assert
      .dom(".insert-link.d-modal__body")
      .doesNotExist("no hyperlink modal by default");

    await click(".d-editor button.link");
    assert.dom(".insert-link.d-modal__body").exists("hyperlink modal visible");

    await fillIn(".d-modal__body .link-url", "google.com");
    await fillIn(".d-modal__body .link-text", "Google");
    await click(".d-modal__footer button.btn-primary");

    assert
      .dom(".d-editor-input")
      .hasValue(
        "This is a link to [Google](https://google.com)",
        "adds link with url and text, prepends 'https://'"
      );

    assert
      .dom(".insert-link.d-modal__body")
      .doesNotExist("modal dismissed after submitting link");

    await fillIn(".d-editor-input", "Reset textarea contents.");

    await click(".d-editor button.link");
    await fillIn(".d-modal__body .link-url", "google.com");
    await fillIn(".d-modal__body .link-text", "Google");
    await click(".d-modal__footer button.btn-danger");

    assert
      .dom(".d-editor-input")
      .hasValue(
        "Reset textarea contents.",
        "doesn’t insert anything after cancelling"
      );

    assert
      .dom(".insert-link.d-modal__body")
      .doesNotExist("modal dismissed after cancelling");

    const textarea = document.querySelector("#reply-control .d-editor-input");
    textarea.selectionStart = 0;
    textarea.selectionEnd = 6;
    await click(".d-editor button.link");

    await fillIn(".d-modal__body .link-url", "somelink.com");
    await click(".d-modal__footer button.btn-primary");

    assert
      .dom(".d-editor-input")
      .hasValue(
        "[Reset](https://somelink.com) textarea contents.",
        "adds link to a selected text"
      );

    await fillIn(".d-editor-input", "");

    await click(".d-editor button.link");
    await fillIn(".d-modal__body .link-url", "http://google.com");
    await triggerKeyEvent(".d-modal__body .link-url", "keyup", "Space");
    assert
      .dom(".internal-link-results")
      .doesNotExist(
        "does not show internal links search dropdown when inputting a url"
      );

    await fillIn(".d-modal__body .link-url", "local");
    await triggerKeyEvent(".d-modal__body .link-url", "keyup", "Space");
    assert
      .dom(".internal-link-results")
      .exists("shows internal links search dropdown when entering keywords");

    await triggerKeyEvent(".insert-link", "keydown", "ArrowDown");
    await triggerKeyEvent(".insert-link", "keydown", "Enter");

    assert
      .dom(".internal-link-results")
      .doesNotExist(
        "search dropdown dismissed after selecting an internal link"
      );

    assert
      .dom(".link-url")
      .hasValue(/http/, "replaces link url field with internal link");

    await triggerKeyEvent(".insert-link", "keydown", "Escape");

    assert
      .dom(".d-editor-input")
      .isFocused(
        "focus stays on composer after dismissing modal using Esc key"
      );
  });
});
