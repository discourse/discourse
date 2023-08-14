import {
  acceptance,
  exists,
  publishToMessageBus,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";

acceptance("Topic - Summary", function (needs) {
  const currentUserId = 5;

  needs.user();
  needs.pretender((server, helper) => {
    server.get("/t/1.json", () => {
      const json = cloneJSON(topicFixtures["/t/130.json"]);
      json.id = 1;
      json.summarizable = true;

      return helper.response(json);
    });

    server.get("/t/1/strategy-summary", () => {
      return helper.response({});
    });
  });

  needs.hooks.beforeEach(() => {
    updateCurrentUser({ id: currentUserId });
  });

  test("displays streamed summary", async function (assert) {
    await visit("/t/-/1");

    const partialSummary = "This a";
    await publishToMessageBus("/summaries/topic/1", {
      done: false,
      topic_summary: { summarized_text: partialSummary },
    });

    await click(".topic-strategy-summarization");

    assert.strictEqual(
      query(".summary-box .generated-summary p").innerText,
      partialSummary,
      "Updates the summary with a partial result"
    );

    const finalSummary = "This is a completed summary";
    await publishToMessageBus("/summaries/topic/1", {
      done: true,
      topic_summary: {
        summarized_text: finalSummary,
        summarized_on: "2023-01-01T04:00:00.000Z",
        algorithm: "OpenAI GPT-4",
        outdated: false,
        new_posts_since_summary: false,
        can_regenerate: true,
      },
    });

    assert.strictEqual(
      query(".summary-box .generated-summary p").innerText,
      finalSummary,
      "Updates the summary with a partial result"
    );

    assert.ok(exists(".summary-box .summarized-on"), "summary metadata exists");
  });
});
