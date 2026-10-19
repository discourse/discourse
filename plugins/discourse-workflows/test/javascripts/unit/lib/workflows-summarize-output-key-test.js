import { module, test } from "qunit";
import {
  summarizeOutputKey,
  summarizeOutputKeyIsDerived,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/summarize-output-key";

module("Unit | lib | discourse-workflows | summarizeOutputKey", function () {
  test("prefers an explicit output field name", function (assert) {
    assert.strictEqual(
      summarizeOutputKey({
        aggregation: "sum",
        field: "like_count",
        output_field_name: "post_likes",
      }),
      "post_likes"
    );
  });

  test("derives a name from the aggregation and field", function (assert) {
    assert.strictEqual(
      summarizeOutputKey({ aggregation: "sum", field: "like_count" }),
      "sum_like_count"
    );
    assert.strictEqual(
      summarizeOutputKey({ aggregation: "count_unique", field: "topic_id" }),
      "unique_count_topic_id"
    );
    assert.strictEqual(
      summarizeOutputKey({ aggregation: "unique", field: "tags" }),
      "unique_tags"
    );
  });

  test("uses the leaf of a dotted field", function (assert) {
    assert.strictEqual(
      summarizeOutputKey({ aggregation: "sum", field: "post.like_count" }),
      "sum_like_count"
    );
  });

  test("uses the full path when derived leaves collide", function (assert) {
    const rows = [
      { aggregation: "count", field: "topic.id" },
      { aggregation: "count", field: "user.id" },
      { aggregation: "sum", field: "post.id" },
    ];

    assert.strictEqual(summarizeOutputKey(rows[0], rows), "count_topic_id");
    assert.strictEqual(summarizeOutputKey(rows[1], rows), "count_user_id");
    assert.strictEqual(summarizeOutputKey(rows[2], rows), "sum_id");
  });

  test("ignores rows with explicit names when checking collisions", function (assert) {
    const rows = [
      { aggregation: "count", field: "topic.id" },
      { aggregation: "count", field: "user.id", output_field_name: "users" },
    ];

    assert.strictEqual(summarizeOutputKey(rows[0], rows), "count_id");
  });

  test("drops the trailing underscore when there is no field", function (assert) {
    assert.strictEqual(summarizeOutputKey({ aggregation: "count" }), "count");
    assert.strictEqual(
      summarizeOutputKey({ aggregation: "collect" }),
      "collected"
    );
  });

  test("sanitizes characters that cannot appear in a key", function (assert) {
    assert.strictEqual(
      summarizeOutputKey({ aggregation: "sum", field: 'a["b c"]' }),
      "sum_ab_c"
    );
  });

  test("ignores whitespace-only explicit names", function (assert) {
    assert.strictEqual(
      summarizeOutputKey({
        aggregation: "count",
        output_field_name: "   ",
      }),
      "count"
    );
  });

  test("reports whether the key was derived", function (assert) {
    assert.true(summarizeOutputKeyIsDerived({ aggregation: "count" }));
    assert.false(
      summarizeOutputKeyIsDerived({
        aggregation: "count",
        output_field_name: "rows",
      })
    );
  });
});
