import { acceptance } from "helpers/qunit-helpers";
import selectKit from "helpers/select-kit-helper";
import pretender from "helpers/create-pretender";

acceptance("User's bookmarks", {
  loggedIn: true,

  beforeEach() {
    pretender.delete("/bookmarks/576", () => [
      200,
      { "Content-Type": "application/json" },
      {}
    ]);
  }
});

test("listing user bookmarks", async assert => {
  await visit("/u/eviltrout/activity/bookmarks-with-reminders");

  assert.ok(find(".bookmark-list-item").length);
});

test("removing a bookmark", async assert => {
  await visit("/u/eviltrout/activity/bookmarks-with-reminders");

  const dropdown = selectKit(".bookmark-actions-dropdown");
  await dropdown.expand();
  await dropdown.selectRowByValue("remove");

  assert.ok(exists(".bootbox.modal"));

  await click(".bootbox.modal .btn-primary");
});

test("listing users bookmarks - no bookmarks", async assert => {
  pretender.get("/u/eviltrout/bookmarks.json", () => [
    200,
    {
      "Content-Type": "application/json"
    },
    {
      bookmarks: [],
      no_results_help: "no bookmarks"
    }
  ]);

  await visit("/u/eviltrout/activity/bookmarks-with-reminders");

  assert.equal(find(".alert.alert-info").text(), "no bookmarks");
});
