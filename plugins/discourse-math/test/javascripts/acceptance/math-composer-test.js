import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Discourse Math - composer", function (needs) {
  needs.user();
  needs.settings({
    discourse_math_enabled: true,
  });

  test("insert block math when at empty line start", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await click(".toolbar-menu__options-trigger");
    await click("[data-name='insert-math']");

    assert.dom(".math-insert-modal").exists("opens the math insert modal");
    assert
      .dom(".math-insert-modal .d-modal__title")
      .hasText("Insert Block Math", "defaults to block mode at empty line");

    await fillIn(".math-insert-modal__textarea", "\\int_0^1 x^2 dx");
    await click(".math-insert-modal__insert");

    assert
      .dom(".d-editor-input")
      .hasValue("$$\n\\int_0^1 x^2 dx\n$$\n", "inserts block math syntax");
  });

  test("insert inline math when in middle of line", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await fillIn(".d-editor-input", "The formula is ");

    await click(".toolbar-menu__options-trigger");
    await click("[data-name='insert-math']");

    assert
      .dom(".math-insert-modal .d-modal__title")
      .hasText(
        "Insert Inline Math",
        "defaults to inline mode when not at line start"
      );

    await fillIn(".math-insert-modal__textarea", "a^2 + b^2 = c^2");
    await click(".math-insert-modal__insert");

    assert
      .dom(".d-editor-input")
      .hasValue(
        "The formula is $a^2 + b^2 = c^2$",
        "inserts inline math after existing text"
      );
  });

  test("toggle from inline to block mode", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await fillIn(".d-editor-input", "Some text ");

    await click(".toolbar-menu__options-trigger");
    await click("[data-name='insert-math']");

    assert
      .dom(".math-insert-modal .d-modal__title")
      .hasText("Insert Inline Math", "starts in inline mode");

    await click(".math-insert-modal__toggle .d-toggle-switch__checkbox");

    assert
      .dom(".math-insert-modal .d-modal__title")
      .hasText("Insert Block Math", "switches to block mode");

    await fillIn(".math-insert-modal__textarea", "E=mc^2");
    await click(".math-insert-modal__insert");

    assert
      .dom(".d-editor-input")
      .hasValue(
        "Some text $$\nE=mc^2\n$$\n",
        "inserts block math when toggled"
      );
  });

  test("toggle from block to inline mode", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await click(".toolbar-menu__options-trigger");
    await click("[data-name='insert-math']");

    assert
      .dom(".math-insert-modal .d-modal__title")
      .hasText("Insert Block Math", "starts in block mode at line start");

    await click(".math-insert-modal__toggle .d-toggle-switch__checkbox");

    assert
      .dom(".math-insert-modal .d-modal__title")
      .hasText("Insert Inline Math", "switches to inline mode");

    await fillIn(".math-insert-modal__textarea", "E=mc^2");
    await click(".math-insert-modal__insert");

    assert.dom(".d-editor-input").hasValue("$E=mc^2$", "inserts inline math");
  });

  test("cancel closes modal without inserting", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await click(".toolbar-menu__options-trigger");
    await click("[data-name='insert-math']");

    await fillIn(".math-insert-modal__textarea", "E=mc^2");
    await click(".math-insert-modal .btn-default");

    assert.dom(".math-insert-modal").doesNotExist("modal is closed");
    assert.dom(".d-editor-input").hasValue("", "nothing was inserted");
  });

  test("empty input shows validation error", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await fillIn(".d-editor-input", "Some text");

    await click(".toolbar-menu__options-trigger");
    await click("[data-name='insert-math']");

    await click(".math-insert-modal__insert");

    assert
      .dom(".math-insert-modal")
      .exists("modal stays open due to validation");
    assert
      .dom(".math-insert-modal .form-kit__errors")
      .exists("shows validation error");
  });
});
