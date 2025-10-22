import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  publishToMessageBus,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

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

    server.get("/discourse-ai/summarization/t/1", () => {
      return helper.response({
        ai_topic_summary: {
          summarized_text: "This a",
        },
        done: false,
      });
    });

    server.get("/discourse-ai/ai-bot/conversations.json", () => {});
  });

  needs.hooks.beforeEach(() => {
    updateCurrentUser({ id: currentUserId });
  });

  test("displays streamed summary", async function (assert) {
    await visit("/t/-/1");

    const partialSummary = "This a";
    await publishToMessageBus("/discourse-ai/summaries/topic/1", {
      done: false,
      ai_topic_summary: { summarized_text: partialSummary },
    });

    await click(".ai-summarization-button");

    assert
      .dom(".ai-summary-box .generated-summary p")
      .hasText(partialSummary, "Updates the summary with a partial result");

    const finalSummary = "This is a completed summary";
    await publishToMessageBus("/discourse-ai/summaries/topic/1", {
      done: true,
      ai_topic_summary: {
        summarized_text: finalSummary,
        summarized_on: "2023-01-01T04:00:00.000Z",
        algorithm: "OpenAI GPT-4",
        outdated: false,
        new_posts_since_summary: false,
        can_regenerate: true,
      },
    });

    assert
      .dom(".ai-summary-box .generated-summary p")
      .hasText(finalSummary, "Updates the summary with a final result");

    assert
      .dom(".ai-summary-modal .summarized-on")
      .exists("summary metadata exists");
  });

  test("clicking summary links", async function (assert) {
    await visit("/t/-/1");

    const partialSummary = "In this post,";
    await publishToMessageBus("/discourse-ai/summaries/topic/1", {
      done: false,
      ai_topic_summary: { summarized_text: partialSummary },
    });

    await click(".ai-summarization-button");
    const finalSummaryCooked =
      "In this post,  <a href='/t/-/1/1'>bianca</a> said some stuff.";
    const finalSummaryResult = "In this post, bianca said some stuff.";
    await publishToMessageBus("/discourse-ai/summaries/topic/1", {
      done: true,
      ai_topic_summary: {
        summarized_text: finalSummaryCooked,
        summarized_on: "2023-01-01T04:00:00.000Z",
        algorithm: "OpenAI GPT-4",
        outdated: false,
        new_posts_since_summary: false,
        can_regenerate: true,
      },
    });

    await click(".generated-summary a");
    assert
      .dom(".ai-summary-box .generated-summary p")
      .hasText(finalSummaryResult, "Retains final summary after clicking link");
  });
});

acceptance("Topic - Summary - Anon", function (needs) {
  const finalSummary = "This is a completed summary";

  needs.pretender((server, helper) => {
    server.get("/t/1.json", () => {
      const json = cloneJSON(topicFixtures["/t/280/1.json"]);
      json.id = 1;
      json.summarizable = true;

      return helper.response(json);
    });

    server.get("/discourse-ai/summarization/t/1", () => {
      return helper.response({
        ai_topic_summary: {
          summarized_text: finalSummary,
          summarized_on: "2023-01-01T04:00:00.000Z",
          algorithm: "OpenAI GPT-4",
          outdated: false,
          new_posts_since_summary: false,
          can_regenerate: false,
        },
      });
    });
  });

  test("displays cached summary immediately", async function (assert) {
    await visit("/t/-/1");

    await click(".ai-summarization-button");

    assert
      .dom(".ai-summary-box .generated-summary p")
      .hasText(finalSummary, "Updates the summary with the result");

    assert
      .dom(".ai-summary-modal .summarized-on")
      .exists("summary metadata exists");
  });

  test("clicking outside of summary should not close the summary box", async function (assert) {
    await visit("/t/-/1");
    await click(".ai-summarization-button");
    await click("#main-outlet-wrapper");
    assert.dom(".ai-summary-box").exists();
  });
});
