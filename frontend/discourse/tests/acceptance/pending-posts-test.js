import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

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
  needs.user({ pending_posts_count: 3 });
  needs.pretender((server, helper) => {
    server.delete("/review/2", () => helper.response({ success: "OK" }));
    server.delete("/review/3", () => helper.response({ success: "OK" }));
  });

  test("Navigate to pending posts", async function (assert) {
    await visit("/u/eviltrout");
    await click("[href='/u/eviltrout/activity/pending']");
    assert.dom(".user-stream-item").exists({ count: 3 });
    assert
      .dom(".user-stream-item:nth-of-type(3)")
      .includesText("A queued topic");
  });

  test("Delete pending posts and topics", async function (assert) {
    await visit("/u/eviltrout/activity/pending");
    await click(".user-stream-item:nth-of-type(1) .btn-danger");

    assert.dom(".user-stream-item").exists({ count: 3 });
    assert.dom(".dialog-body").hasText(i18n("review.delete_confirm"));

    await click(".dialog-footer .btn-danger");

    assert.dom(".user-stream-item").exists({ count: 2 });
    assert.dom(".user-stream-item").doesNotIncludeText("bold text");
    await click(".user-stream-item:nth-of-type(2) .btn-danger");

    assert.dom(".dialog-body").hasText(i18n("review.delete_confirm"));

    await click(".dialog-footer .btn-danger");

    assert.dom(".user-stream-item").exists({ count: 1 });
    assert.dom(".user-stream-item").doesNotIncludeText("A queued topic");
  });
});
