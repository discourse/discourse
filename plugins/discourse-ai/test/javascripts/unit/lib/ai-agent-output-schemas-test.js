import { module, test } from "qunit";
import aiAgentOutputSchemas from "discourse/plugins/discourse-ai/admin/lib/workflows/output-schemas/ai-agent";

module("Unit | lib | discourse-ai | AI agent output schemas", function () {
  test("declares the response format fields next to the raw result", function (assert) {
    const [schema] = aiAgentOutputSchemas({
      agent_response_format: [
        { key: "verdict", type: "string" },
        { key: "confident", type: "boolean" },
        { key: "reasons", type: "array", array_type: "string", max_items: 2 },
      ],
    });

    assert.deepEqual(schema.properties, {
      result: { type: "string" },
      verdict: { type: "string" },
      confident: { type: "boolean" },
      reasons: { type: "array", items: { type: "string" }, maxItems: 2 },
    });
  });

  test("declares only the raw result without usable fields", function (assert) {
    for (const configuration of [
      undefined,
      { agent_response_format: "" },
      { agent_response_format: [{ type: "string" }] },
    ]) {
      assert.deepEqual(
        Object.keys(aiAgentOutputSchemas(configuration)[0].properties),
        ["result"],
        `only result for ${JSON.stringify(configuration)}`
      );
    }
  });
});
