import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Topic Notifications button", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.post("/t/280/notifications", () => {
      return helper.response({});
    });
  });

  test("Updating topic notification level", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-tracking-trigger");
    await click(".topic-tracking-btn[data-level-id='3']");

    assert
      .dom(".topic-tracking-trigger")
      .hasText("Watching", "displays the right notification level");
  });
});
