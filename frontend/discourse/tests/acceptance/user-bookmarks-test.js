import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("User's bookmarks", function (needs) {
  needs.user();

  test("removing a bookmark with no reminder does not show a confirmation", async function (assert) {
    await visit("/u/eviltrout/activity/bookmarks");
    assert.dom(".bookmark-list-item").exists();

    const dropdown = selectKit(".bookmark-actions-dropdown:nth-of-type(1)");
    await dropdown.expand();
    await dropdown.selectRowByValue("remove");

    assert.dom(".dialog-body").doesNotExist("does not show the modal");
  });

  test("it renders search controls if there are bookmarks", async function (assert) {
    await visit("/u/eviltrout/activity/bookmarks");
    assert.dom("div.bookmark-search-form").exists();
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

    server.put("/bookmarks/:id", () => {
      return helper.response({});
    });
  });

  test("removing a bookmark with a reminder shows a confirmation", async function (assert) {
    await visit("/u/eviltrout/activity/bookmarks");

    const dropdown = selectKit(".bookmark-actions-dropdown");
    await dropdown.expand();
    await dropdown.selectRowByValue("remove");

    assert.dom(".dialog-body").exists("asks for delete confirmation");

    await click(".dialog-footer .btn-danger");
    assert.dom(".dialog-body").doesNotExist();
  });

  test("bookmarks with reminders have a clear reminder option", async function (assert) {
    await visit("/u/eviltrout/activity/bookmarks");

    assert.dom(".bookmark-reminder").exists({ count: 2 });

    const dropdown = selectKit(".bookmark-actions-dropdown");
    await dropdown.expand();
    await dropdown.selectRowByValue("clear_reminder");

    assert.dom(".bookmark-reminder").exists({ count: 1 });
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
    assert
      .dom("div.bookmark-search-form")
      .doesNotExist("does not render search controls");
    assert.dom("div.empty-state").exists("renders the empty-state message");
  });
});

acceptance("User's bookmarks - bulk select", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/u/eviltrout/bookmarks.json", () => {
      const json = cloneJSON(userFixtures["/u/eviltrout/bookmarks.json"]);
      const bookmarks = json.user_bookmark_list.bookmarks;
      bookmarks.push({ ...bookmarks[0], id: 9001 });
      return helper.response(json);
    });
  });

  test("shift-clicking selects the bookmarks in between", async function (assert) {
    await visit("/u/eviltrout/activity/bookmarks");
    await click(".bookmark-list thead .bulk-select");

    const checkboxes = "input.bulk-select";
    await click(`.bookmark-list-item:nth-child(1) ${checkboxes}`);
    await click(`.bookmark-list-item:nth-child(3) ${checkboxes}`, {
      shiftKey: true,
    });

    assert
      .dom(`.bookmark-list-item ${checkboxes}:checked`)
      .exists({ count: 3 }, "selects the whole range");
    assert.dom(".bulk-select-bookmarks-dropdown").exists();
  });
});
