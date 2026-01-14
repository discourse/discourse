import { click, fillIn, find, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Details Button", function (needs) {
  needs.user();

  test("details button", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("details.title")}"]`);

    assert
      .dom(".d-editor-input")
      .hasValue(
        `\n[details="${i18n("composer.details_title")}"]\n${i18n(
          "composer.details_text"
        )}\n[/details]\n`,
        "contains the right output"
      );

    await fillIn(".d-editor-input", "This is my title");

    const textarea = find(".d-editor-input");
    textarea.selectionStart = 0;
    textarea.selectionEnd = textarea.value.length;

    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("details.title")}"]`);

    assert
      .dom(".d-editor-input")
      .hasValue(
        `\n[details="${i18n(
          "composer.details_title"
        )}"]\nThis is my title\n[/details]\n`,
        "contains the right selected output"
      );

    assert.strictEqual(
      textarea.selectionStart,
      21,
      "it should start highlighting at the right position"
    );
    assert.strictEqual(
      textarea.selectionEnd,
      37,
      "it should end highlighting at the right position"
    );

    await fillIn(".d-editor-input", "Before some text in between After");

    textarea.selectionStart = 7;
    textarea.selectionEnd = 28;

    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("details.title")}"]`);

    assert
      .dom(".d-editor-input")
      .hasValue(
        `Before \n[details="${i18n(
          "composer.details_title"
        )}"]\nsome text in between\n[/details]\n After`,
        "contains the right output"
      );

    assert.strictEqual(
      textarea.selectionStart,
      28,
      "it should start highlighting at the right position"
    );
    assert.strictEqual(
      textarea.selectionEnd,
      48,
      "it should end highlighting at the right position"
    );

    await fillIn(".d-editor-input", "Before \nsome text in between\n After");

    textarea.selectionStart = 8;
    textarea.selectionEnd = 29;

    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("details.title")}"]`);

    assert
      .dom(".d-editor-input")
      .hasValue(
        `Before \n\n[details="${i18n(
          "composer.details_title"
        )}"]\nsome text in between\n[/details]\n\n After`,
        "contains the right output"
      );

    assert.strictEqual(
      textarea.selectionStart,
      29,
      "it should start highlighting at the right position"
    );
    assert.strictEqual(
      textarea.selectionEnd,
      49,
      "it should end highlighting at the right position"
    );
  });

  test("details button surrounds all selected text in a single details block", async function (assert) {
    const multilineInput = "first line\n\nsecond line\n\nthird line";

    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await fillIn(".d-editor-input", multilineInput);

    const textarea = find(".d-editor-input");
    textarea.selectionStart = 0;
    textarea.selectionEnd = textarea.value.length;

    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("details.title")}"]`);

    assert
      .dom(".d-editor-input")
      .hasValue(
        `\n[details="${i18n(
          "composer.details_title"
        )}"]\n${multilineInput}\n[/details]\n`,
        "contains the right output"
      );
  });
});
