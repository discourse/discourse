import { module, test } from "qunit";
import { isScopedSearch } from "discourse/plugins/discourse-ai/discourse/lib/search-discoveries-context";

module("Unit | Lib | search-discoveries-context", function () {
  test("returns false when there is no search context", function (assert) {
    assert.false(isScopedSearch({}));
    assert.false(isScopedSearch(null));
    assert.false(isScopedSearch(undefined));
  });

  test("returns false on category and tag pages", function (assert) {
    assert.false(
      isScopedSearch({ searchContext: { type: "category" } }),
      "category context still searches globally from the menu"
    );
    assert.false(
      isScopedSearch({ searchContext: { type: "tag" } }),
      "tag context still searches globally from the menu"
    );
    assert.false(
      isScopedSearch({ searchContext: { type: "tagIntersection" } }),
      "tag intersection context still searches globally from the menu"
    );
    assert.false(
      isScopedSearch({ searchContext: { type: "user" } }),
      "user context still searches globally from the menu"
    );
  });

  test("returns true when scoped to a topic", function (assert) {
    assert.true(
      isScopedSearch({
        inTopicContext: true,
        searchContext: { type: "topic" },
      })
    );
  });

  test("returns true when scoped to the PM inbox", function (assert) {
    assert.true(
      isScopedSearch({ searchContext: { type: "private_messages" } })
    );
  });
});
