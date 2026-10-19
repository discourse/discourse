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

  test("a lookup intent never moves a question off the answer", function (assert) {
    assert.deepEqual(
      chooseTab("where is the theme settings page?", {
        topics,
        intent: { intent: "lookup", probability: 0.9 },
      }),
      { tab: "ask", reason: "question" }
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

  test("a reader who prefers results opens on them, even over a confident answer", function (assert) {
    assert.deepEqual(
      chooseTab("how do I reset my password", {
        topics,
        prefersResults: true,
        intent: { intent: "answer", probability: 0.9 },
      }),
      { tab: "topics", reason: "reader_prefers_results" }
    );
  });

  test("a preference for results needs results, and yields to a second search", function (assert) {
    assert.deepEqual(
      chooseTab("password reset", {
        topics: { posts: [] },
        prefersResults: true,
      }),
      { tab: "ask", reason: "no_keyword_matches" }
    );
    assert.deepEqual(
      chooseTab("password reset", {
        topics,
        prefersResults: true,
        searchedAgain: true,
      }),
      { tab: "ask", reason: "searched_again" }
    );
  });

  test("a search about the whole site skips its context", function (assert) {
    const context = { posts: [{ id: 2 }] };
    assert.deepEqual(
      chooseTab("install discourse", {
        topics,
        context,
        scope: "topic:5",
        intent: { scope: "site", scope_probability: 0.9 },
      }),
      { tab: "topics", reason: "topic_results" }
    );
    assert.deepEqual(
      chooseTab("install discourse", {
        topics,
        context,
        scope: "category:3",
        intent: { scope: "site", scope_probability: 0.9 },
      }),
      { tab: "topics", reason: "topic_results" }
    );
  });

  test("an unsure or local scope keeps the context first", function (assert) {
    const context = { posts: [{ id: 2 }] };
    assert.deepEqual(
      chooseTab("deadline", {
        topics,
        context,
        scope: "topic:5",
        intent: { scope: "site", scope_probability: 0.6 },
      }),
      { tab: "context", reason: "topic_match" }
    );
    assert.deepEqual(
      chooseTab("deadline", {
        topics,
        context,
        scope: "topic:5",
        intent: { scope: "here", scope_probability: 0.9 },
      }),
      { tab: "context", reason: "topic_match" }
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
