import { module, test } from "qunit";
import summarizeOutputSchemas from "discourse/plugins/discourse-workflows/admin/lib/workflows/output-schemas/summarize";

module(
  "Unit | lib | discourse-workflows | summarize output schemas",
  function () {
    test("derives properties from group keys and aggregations", function (assert) {
      const [schema] = summarizeOutputSchemas({
        fields_to_split_by: "topic_id",
        fields_to_summarize: {
          values: [
            {
              aggregation: "sum",
              field: "likes",
              output_field_name: "post_likes",
            },
            { aggregation: "count" },
          ],
        },
      });

      assert.deepEqual(Object.keys(schema.properties), [
        "topic_id",
        "post_likes",
        "count",
      ]);
      assert.strictEqual(schema.properties.count.type, "integer");
      assert.deepEqual(schema.properties.post_likes.type, ["number", "null"]);
    });

    test("takes the leaf of a dotted group key", function (assert) {
      const [schema] = summarizeOutputSchemas({
        fields_to_split_by: "post.topic_id, tags",
      });

      assert.deepEqual(Object.keys(schema.properties), ["topic_id", "tags"]);
    });

    test("resolves an empty shape without configuration", function (assert) {
      const [schema] = summarizeOutputSchemas();

      assert.deepEqual(schema.properties, {});
    });
  }
);
