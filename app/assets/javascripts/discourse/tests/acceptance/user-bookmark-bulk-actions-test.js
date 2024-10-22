import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  count,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";

acceptance("Bookmark - Bulk Actions", function (needs) {
  needs.user();

  test("bulk select - modal", async function (assert) {
    await visit("/u/eviltrout/activity/bookmarks");
    assert.dom("button.bulk-select").exists();

    await click("button.bulk-select");

    await click(queryAll("input.bulk-select")[0]);
    await click(queryAll("input.bulk-select")[1]);

    const dropdown = selectKit(".select-kit.bulk-select-bookmarks-dropdown");
    await dropdown.expand();

    await dropdown.selectRowByValue("clear-reminders");

    assert.ok(exists(".dialog-container"), "it should show the modal");
    assert.dom(".dialog-container .dialog-body").includesText(
      I18n.t("js.bookmark_bulk_actions.clear_reminders.description", {
        count: 2,
      }).replaceAll(/\<.*?>/g, "")
    );

    await click("button.bulk-clear-all");

    assert.strictEqual(
      count("input.bulk-select:checked"),
      0,
      "Clear all should clear all selection"
    );

    await click("button.bulk-select-all");

    assert.strictEqual(
      count("input.bulk-select:checked"),
      2,
      "Select all should select all topics"
    );

    await dropdown.expand();
    await dropdown.selectRowByValue("delete-bookmarks");

    assert.ok(exists(".dialog-container"), "it should show the modal");

    assert.dom(".dialog-container .dialog-body").includesText(
      I18n.t("js.bookmark_bulk_actions.delete_bookmarks.description", {
        count: 2,
      }).replaceAll(/\<.*?>/g, "")
    );
  });
});
