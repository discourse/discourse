import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import { setupApplicationTest as EMBER_CLI_ENV } from "ember-qunit";

acceptance("Pending posts - no existing pending posts", function (needs) {
  if (!EMBER_CLI_ENV) {
    return; // dom helpers not available in legacy env
  }

  needs.user();

  test("No link to pending posts", async function (assert) {
    await visit("/u/eviltrout");
    assert.dom(".action-list").doesNotIncludeText("Pending");
  });
});

acceptance("Pending posts - existing pending posts", function (needs) {
  if (!EMBER_CLI_ENV) {
    return; // dom helpers not available in legacy env
  }

  needs.user({ pending_posts_count: 2 });

  test("Navigate to pending posts", async function (assert) {
    await visit("/u/eviltrout");
    await click("[href='/u/eviltrout/activity/pending']");
    assert.dom(".user-stream-item").exists({ count: 2 });
  });
});
