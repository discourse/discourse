import { acceptance } from "helpers/qunit-helpers";

acceptance("User Drafts", { loggedIn: true });

QUnit.test("Stream", async assert => {
  await visit("/u/eviltrout/activity/drafts");
  assert.ok(find(".user-stream-item").length === 3, "has drafts");

  await click(".user-stream-item:last-child .remove-draft");
  assert.ok(
    find(".user-stream-item").length === 2,
    "draft removed, list length diminished by one"
  );
});
