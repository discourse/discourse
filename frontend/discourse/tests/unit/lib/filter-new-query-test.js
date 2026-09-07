import { module, test } from "qunit";
import {
  filterNewQuery,
  parseFilterNewQuery,
} from "discourse/lib/filter-new-query";

module("Unit | Lib | filter-new-query", function () {
  test("switches subsets without changing other conditions", function (assert) {
    const base =
      'category:announcements category:bug status:open order:likes "some words"';
    assert.strictEqual(
      filterNewQuery(`${base} in:new`, "topics"),
      `${base} in:new-topics`,
      "replaces the selector"
    );
    assert.strictEqual(
      filterNewQuery(`${base} in:new-replies`),
      base,
      "All removes only the selector"
    );
    assert.strictEqual(
      filterNewQuery(base, "all"),
      `${base} in:new`,
      "New selects both subsets"
    );
  });

  test("preserves other in values and quoted text", function (assert) {
    assert.strictEqual(
      filterNewQuery(
        'in:bookmarked,new in:new-topics "in:new" tag:"some tag"',
        "replies"
      ),
      'in:bookmarked "in:new" tag:"some tag" in:new-replies',
      "only complete New values are replaced"
    );
    assert.strictEqual(
      parseFilterNewQuery('in:"new-replies"').selection,
      undefined,
      "preserves unsupported quoted selectors"
    );
    assert.strictEqual(
      parseFilterNewQuery('"in:new" in:newest').selection,
      undefined,
      "ignores text and unrelated values"
    );
  });

  test("identifies conflicting and repeated selectors", function (assert) {
    assert.strictEqual(
      parseFilterNewQuery("in:new-topics in:new-replies").selection,
      "mixed",
      "conflicting selectors have no selected subset"
    );
    assert.strictEqual(
      parseFilterNewQuery("in:new in:new").selection,
      "all",
      "duplicate selectors identify one subset"
    );
    assert.strictEqual(
      filterNewQuery("in:new-topics in:new-replies", "all"),
      "in:new",
      "a selection resolves conflicts"
    );
  });
});
