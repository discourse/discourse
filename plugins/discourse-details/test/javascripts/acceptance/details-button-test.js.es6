import { acceptance } from "helpers/qunit-helpers";
import { clearPopupMenuOptionsCallback } from "discourse/controllers/composer";
import selectKit from "helpers/select-kit-helper";

acceptance("Details Button", {
  loggedIn: true,
  beforeEach: function() {
    clearPopupMenuOptionsCallback();
  }
});

test("details button", async assert => {
  const popupMenu = selectKit(".toolbar-popup-menu-options");

  await visit("/");
  await click("#create-topic");

  await popupMenu.expand();
  await popupMenu.selectRowByValue("insertDetails");

  assert.equal(
    find(".d-editor-input").val(),
    `\n[details="${I18n.t("composer.details_title")}"]\n${I18n.t(
      "composer.details_text"
    )}\n[/details]\n`,
    "it should contain the right output"
  );

  await fillIn(".d-editor-input", "This is my title");

  const textarea = find(".d-editor-input")[0];
  textarea.selectionStart = 0;
  textarea.selectionEnd = textarea.value.length;

  await popupMenu.expand();
  await popupMenu.selectRowByValue("insertDetails");

  assert.equal(
    find(".d-editor-input").val(),
    `\n[details="${I18n.t(
      "composer.details_title"
    )}"]\nThis is my title\n[/details]\n`,
    "it should contain the right selected output"
  );

  assert.equal(
    textarea.selectionStart,
    21,
    "it should start highlighting at the right position"
  );
  assert.equal(
    textarea.selectionEnd,
    37,
    "it should end highlighting at the right position"
  );

  await fillIn(".d-editor-input", "Before some text in between After");

  textarea.selectionStart = 7;
  textarea.selectionEnd = 28;

  await popupMenu.expand();
  await popupMenu.selectRowByValue("insertDetails");

  assert.equal(
    find(".d-editor-input").val(),
    `Before \n[details="${I18n.t(
      "composer.details_title"
    )}"]\nsome text in between\n[/details]\n After`,
    "it should contain the right output"
  );

  assert.equal(
    textarea.selectionStart,
    28,
    "it should start highlighting at the right position"
  );
  assert.equal(
    textarea.selectionEnd,
    48,
    "it should end highlighting at the right position"
  );

  await fillIn(".d-editor-input", "Before \nsome text in between\n After");

  textarea.selectionStart = 8;
  textarea.selectionEnd = 29;

  await popupMenu.expand();
  await popupMenu.selectRowByValue("insertDetails");

  assert.equal(
    find(".d-editor-input").val(),
    `Before \n\n[details="${I18n.t(
      "composer.details_title"
    )}"]\nsome text in between\n[/details]\n\n After`,
    "it should contain the right output"
  );

  assert.equal(
    textarea.selectionStart,
    29,
    "it should start highlighting at the right position"
  );
  assert.equal(
    textarea.selectionEnd,
    49,
    "it should end highlighting at the right position"
  );
});

test("details button surrounds all selected text in a single details block", async assert => {
  const multilineInput = "first line\n\nsecond line\n\nthird line";
  const popupMenu = selectKit(".toolbar-popup-menu-options");

  await visit("/");
  await click("#create-topic");
  await fillIn(".d-editor-input", multilineInput);

  const textarea = find(".d-editor-input")[0];
  textarea.selectionStart = 0;
  textarea.selectionEnd = textarea.value.length;

  await popupMenu.expand();
  await popupMenu.selectRowByValue("insertDetails");

  assert.equal(
    find(".d-editor-input").val(),
    `\n[details="${I18n.t(
      "composer.details_title"
    )}"]\n${multilineInput}\n[/details]\n`,
    "it should contain the right output"
  );
});
