import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from 'discourse-i18n';

acceptance("Details Button", function (needs) {
  needs.user();

  test("details button", async function (assert) {
    const popupMenu = selectKit(".toolbar-popup-menu-options");

    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await popupMenu.expand();
    await popupMenu.selectRowByName(i18n("details.title"));

    assert.strictEqual(
      query(".d-editor-input").value,
      `\n[details="${i18n("composer.details_title")}"]\n${i18n(
        "composer.details_text"
      )}\n[/details]\n`,
      "it should contain the right output"
    );

    await fillIn(".d-editor-input", "This is my title");

    const textarea = query(".d-editor-input");
    textarea.selectionStart = 0;
    textarea.selectionEnd = textarea.value.length;

    await popupMenu.expand();
    await popupMenu.selectRowByName(i18n("details.title"));

    assert.strictEqual(
      query(".d-editor-input").value,
      `\n[details="${i18n(
        "composer.details_title"
      )}"]\nThis is my title\n[/details]\n`,
      "it should contain the right selected output"
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

    await popupMenu.expand();
    await popupMenu.selectRowByName(i18n("details.title"));

    assert.strictEqual(
      query(".d-editor-input").value,
      `Before \n[details="${i18n(
        "composer.details_title"
      )}"]\nsome text in between\n[/details]\n After`,
      "it should contain the right output"
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

    await popupMenu.expand();
    await popupMenu.selectRowByName(i18n("details.title"));

    assert.strictEqual(
      query(".d-editor-input").value,
      `Before \n\n[details="${i18n(
        "composer.details_title"
      )}"]\nsome text in between\n[/details]\n\n After`,
      "it should contain the right output"
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
    const popupMenu = selectKit(".toolbar-popup-menu-options");

    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await fillIn(".d-editor-input", multilineInput);

    const textarea = query(".d-editor-input");
    textarea.selectionStart = 0;
    textarea.selectionEnd = textarea.value.length;

    await popupMenu.expand();
    await popupMenu.selectRowByName(i18n("details.title"));

    assert.strictEqual(
      query(".d-editor-input").value,
      `\n[details="${i18n(
        "composer.details_title"
      )}"]\n${multilineInput}\n[/details]\n`,
      "it should contain the right output"
    );
  });
});
