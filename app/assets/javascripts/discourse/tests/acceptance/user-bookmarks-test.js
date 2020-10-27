import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { cloneJSON } from "discourse-common/lib/object";

acceptance("User's bookmarks", function (needs) {
  needs.user();

  test("removing a bookmark with no reminder does not show a confirmation", async (assert) => {
    await visit("/u/eviltrout/activity/bookmarks");
    assert.ok(find(".bookmark-list-item").length > 0);

    const dropdown = selectKit(".bookmark-actions-dropdown:eq(0)");
    await dropdown.expand();
    await dropdown.selectRowByValue("remove");

    assert.not(exists(".bootbox.modal"), "it should not show the modal");
  });
});

acceptance("User's bookmarks - reminder", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/u/eviltrout/bookmarks.json", () => {
      let json = cloneJSON(userFixtures["/u/eviltrout/bookmarks.json"]);
      json.user_bookmark_list.bookmarks[0].reminder_at = "2028-01-01T08:00";
      return helper.response(json);
    });
  });

  test("removing a bookmark with a reminder shows a confirmation", async (assert) => {
    await visit("/u/eviltrout/activity/bookmarks");

    const dropdown = selectKit(".bookmark-actions-dropdown");
    await dropdown.expand();
    await dropdown.selectRowByValue("remove");

    assert.ok(exists(".bootbox.modal"), "it asks for delete confirmation");

    await click(".bootbox.modal a.btn-primary");
    assert.not(exists(".bootbox.modal"));
  });
});

acceptance("User's bookmarks - no bookmarks", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/u/eviltrout/bookmarks.json", () =>
      helper.response({
        bookmarks: [],
        no_results_help: "no bookmarks",
      })
    );
  });

  test("listing users bookmarks - no bookmarks", async (assert) => {
    await visit("/u/eviltrout/activity/bookmarks");
    assert.equal(find(".alert.alert-info").text(), "no bookmarks");
  });
});
