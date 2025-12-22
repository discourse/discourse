import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Category Edit | Topic Voting", function (needs) {
  needs.user();
  needs.settings({ topic_voting_enabled: true });

  test("Enabling topic voting sends boolean true", async function (assert) {
    await visit("/c/bug/edit/settings");
    await click(".enable-topic-voting input[type='checkbox']");
    await click("#save-category");

    const payload = JSON.parse(
      pretender.handledRequests[pretender.handledRequests.length - 1]
        .requestBody
    );
    assert.true(
      payload.custom_fields.enable_topic_voting,
      "enable_topic_voting should be boolean true"
    );
  });

  test("Disabling topic voting sends boolean false", async function (assert) {
    await visit("/c/bug/edit/settings");

    // twice to toggle false
    await click(".enable-topic-voting input[type='checkbox']");
    await click(".enable-topic-voting input[type='checkbox']");

    await click("#save-category");

    const payload = JSON.parse(
      pretender.handledRequests[pretender.handledRequests.length - 1]
        .requestBody
    );
    assert.false(
      payload.custom_fields.enable_topic_voting,
      "enable_topic_voting should be boolean false"
    );
  });

  test("Modifying other settings does not include enable_topic_voting", async function (assert) {
    await visit("/c/bug/edit/settings");
    await click("#save-category");

    const payload = JSON.parse(
      pretender.handledRequests[pretender.handledRequests.length - 1]
        .requestBody
    );
    assert.strictEqual(
      payload.custom_fields?.enable_topic_voting,
      undefined,
      "enable_topic_voting should not be in payload when not modified"
    );
  });
});
