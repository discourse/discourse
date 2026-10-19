import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { chooseTab } from "discourse/plugins/discourse-ai/discourse/lib/ai-search-intent";

const topics = { posts: [{ id: 1 }] };

module("Discourse AI | Unit | Lib | ai-search-intent", function (hooks) {
  setupTest(hooks);

  test("a confident answer intent opens on Ask AI", function (assert) {
    assert.deepEqual(
      chooseTab("password reset", {
        topics,
        intent: { intent: "answer", probability: 0.9 },
      }),
      { tab: "ask", reason: "intent_answer" }
    );
  });

  test("a confident lookup intent opens on the results, however the query reads", function (assert) {
    assert.deepEqual(
      chooseTab("where is the theme settings page?", {
        topics,
        intent: { intent: "lookup", probability: 0.9 },
      }),
      { tab: "topics", reason: "topic_results" }
    );
  });

  test("an unsure intent falls back to how the query reads", function (assert) {
    assert.deepEqual(
      chooseTab("where is the theme settings page?", {
        topics,
        intent: { intent: "lookup", probability: 0.55 },
      }),
      { tab: "ask", reason: "question" }
    );
    assert.deepEqual(
      chooseTab("password reset", {
        topics,
        intent: { intent: "answer", probability: 0.55 },
      }),
      { tab: "topics", reason: "topic_results" }
    );
  });

  test("search syntax wins over the intent", function (assert) {
    assert.deepEqual(
      chooseTab('"reset password"', {
        topics,
        intent: { intent: "answer", probability: 0.9 },
      }),
      { tab: "topics", reason: "syntax" }
    );
  });

  test("a lookup with no keyword matches still opens on Ask AI", function (assert) {
    assert.deepEqual(
      chooseTab("password reset", {
        topics: { posts: [] },
        intent: { intent: "lookup", probability: 0.9 },
      }),
      { tab: "ask", reason: "no_keyword_matches" }
    );
  });
});
