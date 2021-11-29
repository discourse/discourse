import {
  acceptance,
  count,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";

acceptance("Pending posts - no existing pending posts", function (needs) {
  needs.user();

  test("No link to pending posts", async function (assert) {
    await visit("/u/eviltrout");
    assert.ok(!exists(".action-list [href='/u/eviltrout/activity/pending']"));
  });
});

acceptance("Pending posts - existing pending posts", function (needs) {
  needs.user({ pending_posts_count: 2 });

  test("Navigate to pending posts", async function (assert) {
    await visit("/u/eviltrout");
    await click("[href='/u/eviltrout/activity/pending']");
    assert.strictEqual(count(".user-stream-item"), 2);
  });
});
