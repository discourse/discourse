import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Category Edit", function (needs) {
  needs.user();
  needs.settings({ post_voting_enabled: true });

  test("Editing the category to create_as_post_voting_default", async function (assert) {
    await visit("/c/bug/edit/settings");
    await click("#create-as-post-voting-default");

    await click("#save-category");

    const payload = JSON.parse(
      pretender.handledRequests[pretender.handledRequests.length - 1]
        .requestBody
    );
    assert.true(payload.custom_fields.create_as_post_voting_default);
  });

  test("Editing the category to only_post_voting_in_this_category", async function (assert) {
    await visit("/c/bug/edit/settings");
    await click("#only-post-voting-in-this-category");

    await click("#save-category");

    const payload = JSON.parse(
      pretender.handledRequests[pretender.handledRequests.length - 1]
        .requestBody
    );
    assert.true(payload.custom_fields.only_post_voting_in_this_category);
  });
});
