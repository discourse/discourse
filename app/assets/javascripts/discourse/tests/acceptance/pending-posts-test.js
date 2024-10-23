import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, count } from "discourse/tests/helpers/qunit-helpers";

acceptance("Pending posts - no existing pending posts", function (needs) {
  needs.user();

  test("No link to pending posts", async function (assert) {
    await visit("/u/eviltrout");
    assert
      .dom(".action-list [href='/u/eviltrout/activity/pending']")
      .doesNotExist();
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
