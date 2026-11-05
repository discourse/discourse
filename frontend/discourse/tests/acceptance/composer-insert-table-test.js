import { click, fillIn, find, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const TABLE = [
  "| Column 1 | Column 2 | Column 3 | Column 4 |",
  "| --- | --- | --- | --- |",
  "|  |  |  |  |",
].join("\n");

async function insertTable() {
  await click(".toolbar-menu__options-trigger");
  await click("button[data-name='toggle-spreadsheet']");
}

acceptance("Composer - Insert table | Markdown editor", function (needs) {
  needs.user({
    "user_option.composition_mode": USER_OPTION_COMPOSITION_MODES.markdown,
  });

  test("inserts a Markdown table into a reply", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .create");
    await fillIn(".d-editor-input", "Some text");
    await insertTable();

    assert
      .dom(".d-editor-input")
      .hasValue(
        `Some text\n\n${TABLE}\n`,
        "the table starts on its own line, ready to edit"
      );
  });

  test("inserts a Markdown table when editing a post", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#post_1 .show-more-actions");
    await click("#post_1 .edit");
    await insertTable();

    assert.true(
      find(".d-editor-input").value.includes(TABLE),
      "the table is added to the post's Markdown"
    );
  });
});

acceptance("Composer - Insert table | rich editor", function (needs) {
  needs.user({
    "user_option.composition_mode": USER_OPTION_COMPOSITION_MODES.rich,
  });

  test("inserts a table with editing controls", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await waitFor("#reply-control .ProseMirror");
    await insertTable();

    assert
      .dom("#reply-control .ProseMirror table th")
      .exists({ count: 4 }, "the table has four columns");
    assert
      .dom("#reply-control .ProseMirror table th")
      .hasText("Column 1", "the columns have default headings");
    assert
      .dom("#reply-control .ProseMirror .composer-table__append")
      .exists("the structural editing controls are available");
  });
});
