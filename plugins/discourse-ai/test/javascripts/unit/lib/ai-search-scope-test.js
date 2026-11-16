import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  contextPlace,
  scopeFilter,
} from "discourse/plugins/discourse-ai/discourse/lib/ai-search-scope";

module("Discourse AI | Unit | Lib | ai-search-scope", function (hooks) {
  setupTest(hooks);

  test("a tag page within a category scopes to both", function (assert) {
    const place = contextPlace({
      type: "tagIntersection",
      tagId: "how-to",
      additionalTags: ["faq"],
      categoryId: 12,
      category: { name: "Support" },
    });

    assert.strictEqual(place.key, "category:12 tag:how-to+faq");
    assert.strictEqual(place.tabLabel, "Support #how-to #faq");
    assert.strictEqual(
      scopeFilter(place.key),
      "category:12 tags:how-to+faq",
      "and searches for topics with every tag"
    );
  });

  test("an intersection of tags alone scopes to every tag", function (assert) {
    const place = contextPlace({
      type: "tagIntersection",
      tagId: "how-to",
      additionalTags: ["faq"],
    });

    assert.strictEqual(place.key, "tag:how-to+faq");
  });

  test("a key with an unknown part has no filter", function (assert) {
    assert.strictEqual(scopeFilter("category:12 order:latest"), null);
  });
});
