import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { applyValueTransformer } from "discourse/lib/transformer";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("AI semantic search result classes", function (needs) {
  needs.settings({ discourse_ai_enabled: true });

  test("marks AI-generated search results", async function (assert) {
    await visit("/");

    assert.deepEqual(
      applyValueTransformer("search-result-entry-class", [], {
        post: { generatedByAi: true },
      }),
      ["ai-result"],
      "adds the class for AI results"
    );
    assert.deepEqual(
      applyValueTransformer("search-result-entry-class", [], {
        post: {},
      }),
      [],
      "leaves other results alone"
    );
  });
});
