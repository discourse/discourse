import { module, test } from "qunit";
import {
  isCompleteSegment,
  parseFilterToken,
  splitCommittedSegments,
  splitFilterQuery,
} from "discourse/lib/filter-query-tokens";

module("Unit | Lib | filter-query-tokens", function () {
  test("splitFilterQuery keeps quoted values together", function (assert) {
    assert.deepEqual(splitFilterQuery(`tag_group:"foo bar" status:open`), [
      `tag_group:"foo bar"`,
      "status:open",
    ]);
    assert.deepEqual(splitFilterQuery("don't stop"), ["don't", "stop"]);
    assert.deepEqual(splitFilterQuery(""), []);
    assert.deepEqual(splitFilterQuery(undefined), []);
  });

  test("parseFilterToken", function (assert) {
    assert.deepEqual(parseFilterToken("-=category:bugs"), {
      raw: "-=category:bugs",
      prefix: "-=",
      filterName: "category",
      value: "bugs",
    });
    assert.strictEqual(parseFilterToken("hello").filterName, null);
    assert.strictEqual(parseFilterToken(":oops").filterName, null);
  });

  test("splitCommittedSegments", function (assert) {
    assert.deepEqual(splitCommittedSegments("category:bugs sta"), {
      committed: ["category:bugs"],
      draft: "sta",
    });
    assert.deepEqual(splitCommittedSegments("status:open "), {
      committed: ["status:open"],
      draft: "",
    });
    assert.deepEqual(splitCommittedSegments("category:bug"), {
      committed: [],
      draft: "category:bug",
    });
    assert.deepEqual(
      splitCommittedSegments(`tag_group:"foo bar`),
      { committed: [], draft: `tag_group:"foo bar` },
      "an open quote keeps the segment in the draft"
    );
    assert.deepEqual(
      splitCommittedSegments("don't stop"),
      { committed: ["don't"], draft: "stop" },
      "apostrophes inside words are not quotes"
    );
  });

  test("isCompleteSegment", function (assert) {
    assert.true(isCompleteSegment("category:bugs"));
    assert.true(isCompleteSegment("hello"));
    assert.false(isCompleteSegment("category:"));
    assert.false(isCompleteSegment("tag:a,"));
    assert.false(isCompleteSegment(""));
  });
});
