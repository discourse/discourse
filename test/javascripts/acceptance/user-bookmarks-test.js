import { acceptance } from "helpers/qunit-helpers";
import selectKit from "helpers/select-kit-helper";
import pretender from "helpers/create-pretender";
import userFixtures from "fixtures/user_fixtures";

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
  await visit("/u/eviltrout/activity/bookmarks");

  assert.ok(find(".bookmark-list-item").length);
});

test("removing a bookmark with a reminder shows a confirmation", async assert => {
  let listResponse = _.clone(userFixtures["/u/eviltrout/bookmarks.json"]);
  listResponse.user_bookmark_list.bookmarks[0].reminder_at = "2028-01-01T08:00";
  pretender.get("/u/eviltrout/bookmarks.json", () => [
    200,
    { "Content-Type": "application/json" },
    listResponse
  ]);
  await visit("/u/eviltrout/activity/bookmarks");

  const dropdown = selectKit(".bookmark-actions-dropdown");
  await dropdown.expand();
  await dropdown.selectRowByValue("remove");

  assert.ok(exists(".bootbox.modal"), "it asks for delete confirmation");

  await click(".bootbox.modal a.btn-primary");
  assert.not(exists(".bootbox.modal"));
  listResponse.user_bookmark_list.bookmarks[0].reminder_at = null;
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

  await visit("/u/eviltrout/activity/bookmarks");

  assert.equal(find(".alert.alert-info").text(), "no bookmarks");
});

test("removing a bookmark with no reminder does not show a confirmation", async assert => {
  await visit("/u/eviltrout/activity/bookmarks");

  const dropdown = selectKit(".bookmark-actions-dropdown");
  await dropdown.expand();
  await dropdown.selectRowByValue("remove");

  assert.not(exists(".bootbox.modal"), "it should not show the modal");
});
