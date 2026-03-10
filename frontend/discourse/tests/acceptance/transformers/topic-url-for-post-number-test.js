import { getOwner } from "@ember/owner";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("topic-url-for-post-number transformer", function (needs) {
  needs.user();

  test("applying a value transformation", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("topic-url-for-post-number", ({ value }) => {
        return "/custom" + value;
      });
    });

    await visit("/t/internationalization-localization/280");

    const topicController = getOwner(this).lookup("controller:topic");
    const topic = topicController.model;

    assert.true(
      topic.urlForPostNumber(1).startsWith("/custom"),
      "it transforms the topic url for post number"
    );
  });

  test("transformer receives the topic and postNumber in context", async function (assert) {
    let receivedContext;

    withPluginApi((api) => {
      api.registerValueTransformer(
        "topic-url-for-post-number",
        ({ value, context }) => {
          receivedContext = context;
          return value;
        }
      );
    });

    await visit("/t/internationalization-localization/280");

    const topicController = getOwner(this).lookup("controller:topic");
    const topic = topicController.model;
    topic.urlForPostNumber(3);

    assert.strictEqual(
      receivedContext.topic,
      topic,
      "transformer receives the topic in context"
    );
    assert.strictEqual(
      receivedContext.postNumber,
      3,
      "transformer receives the postNumber in context"
    );
  });
});
