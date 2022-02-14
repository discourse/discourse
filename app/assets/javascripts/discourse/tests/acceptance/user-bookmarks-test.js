import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import userFixtures from "discourse/tests/fixtures/user-fixtures";

acceptance("User's bookmarks", function (needs) {
  needs.user();

  test("removing a bookmark with no reminder does not show a confirmation", async function (assert) {
    await visit("/u/eviltrout/activity/bookmarks");
    assert.ok(exists(".bookmark-list-item"));

    const dropdown = selectKit(".bookmark-actions-dropdown:nth-of-type(1)");
    await dropdown.expand();
    await dropdown.selectRowByValue("remove");

    assert.notOk(exists(".bootbox.modal"), "it should not show the modal");
  });

  test("it renders search controls if there are bookmarks", async function (assert) {
    await visit("/u/eviltrout/activity/bookmarks");
    assert.ok(exists("div.bookmark-search-form"));
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

  test("removing a bookmark with a reminder shows a confirmation", async function (assert) {
    await visit("/u/eviltrout/activity/bookmarks");

    const dropdown = selectKit(".bookmark-actions-dropdown");
    await dropdown.expand();
    await dropdown.selectRowByValue("remove");

    assert.ok(exists(".bootbox.modal"), "it asks for delete confirmation");

    await click(".bootbox.modal a.btn-primary");
    assert.notOk(exists(".bootbox.modal"));
  });
});

acceptance("User's bookmarks - no bookmarks", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/u/eviltrout/bookmarks.json", () =>
      helper.response({
        bookmarks: [],
      })
    );
  });

  test("listing users bookmarks - no bookmarks", async function (assert) {
    await visit("/u/eviltrout/activity/bookmarks");
    assert.notOk(
      exists("div.bookmark-search-form"),
      "does not render search controls"
    );
    assert.ok(exists("div.empty-state", "renders the empty-state message"));
  });
});
