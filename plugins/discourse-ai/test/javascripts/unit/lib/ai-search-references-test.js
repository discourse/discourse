import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import AiSearchReferences, {
  citedTopicsFromRaw,
  topicIdFromUrl,
} from "discourse/plugins/discourse-ai/discourse/lib/ai-search-references";

function item(topicId) {
  return { topicId, title: `Topic ${topicId}`, url: `/t/topic/${topicId}` };
}

module("Discourse AI | Unit | Lib | ai-search-references", function (hooks) {
  setupTest(hooks);

  test("topicIdFromUrl", function (assert) {
    assert.strictEqual(topicIdFromUrl("https://x.com/t/some-slug/123/4"), 123);
    assert.strictEqual(topicIdFromUrl("/t/456"), 456);
    assert.strictEqual(topicIdFromUrl("/u/someone"), null);
  });

  test("citedTopicsFromRaw keeps first mention of each topic", function (assert) {
    const raw =
      "See [Setup guide](/t/setup-guide/10) and [again](/t/setup-guide/10/3), plus [FAQ](https://x.com/t/faq/20).";

    assert.deepEqual(
      citedTopicsFromRaw(raw).map(({ topicId, title }) => [topicId, title]),
      [
        [10, "Setup guide"],
        [20, "FAQ"],
      ]
    );
  });

  test("topics seen across signals outrank single-signal topics", function (assert) {
    const references = new AiSearchReferences();
    references.add(0, "keyword", [item(1), item(2)]);
    references.add(0, "semantic", [item(2), item(3)]);

    assert.strictEqual(references.rank(0)[0].topicId, 2);
  });

  test("later turns rerank and report movement", function (assert) {
    const references = new AiSearchReferences();
    references.add(0, "keyword", [item(1), item(2)]);
    references.rank(0);

    references.add(1, "cited", [item(2), item(3)]);
    const ranked = references.rank(1);

    assert.deepEqual(
      ranked.map((entry) => entry.topicId),
      [2, 3, 1]
    );
    assert.strictEqual(ranked[0].movement, 1, "moved up one place");
    assert.true(ranked[1].isNew, "newly surfaced topic is flagged");
    assert.true(ranked[0].citedNow);
    assert.strictEqual(ranked[2].movement, -2);
  });

  test("excluded topics never rank", function (assert) {
    const references = new AiSearchReferences();
    references.exclude(2);
    references.add(0, "keyword", [item(1), item(2)]);

    assert.deepEqual(
      references.rank(0).map((entry) => entry.topicId),
      [1]
    );
  });
});
