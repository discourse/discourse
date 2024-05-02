import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  exists,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";

acceptance("Bookmark - Bulk Actions", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.put("/bookmarks/bulk", () => {
      return helper.response({
        bookmark_ids: [],
      });
    });
  });

  test("bulk select - options", async function (assert) {
    updateCurrentUser({ moderator: true });
    await visit("/u/eviltrout/activity/bookmarks");
    assert.ok(exists("button.bulk-select"));

    await click("button.bulk-select");

    await click(queryAll("input.bulk-select")[0]);
    await click(queryAll("input.bulk-select")[1]);

    const dropdown = selectKit(".select-kit.bulk-select-bookmarks-dropdown");
    await dropdown.expand();

    const options = dropdown.displayedContent();

    assert.strictEqual(
      options[0].name,
      I18n.t("js.bookmark_bulk_actions.clear_reminders.name"),
      "it shows an option to clear reminders"
    );

    assert.strictEqual(
      options[1].name,
      I18n.t("js.bookmark_bulk_actions.delete_bookmarks.name"),
      "it shows an option to delete bookmarks"
    );
  });

  test("bulk select - clear reminders", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/u/eviltrout/activity/bookmarks");
    assert.ok(exists("button.bulk-select"));

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
  });
});
