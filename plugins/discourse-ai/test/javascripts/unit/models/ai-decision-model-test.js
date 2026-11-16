import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AiDecisionModel from "discourse/plugins/discourse-ai/discourse/admin/models/ai-decision-model";

module("Unit | Model | ai-decision-model", function (hooks) {
  setupTest(hooks);

  test("tests the draft configuration as JSON to preserve header arrays", async function (assert) {
    const config = {
      name: "test-model",
      custom_headers: [{ name: "X-Image-Input", value: "true" }],
    };
    pretender.post(
      "/admin/plugins/discourse-ai/ai-decision-models/test.json",
      (request) => {
        assert.true(
          request.requestHeaders["Content-Type"].startsWith("application/json"),
          "sends JSON rather than indexed form parameters"
        );
        assert.deepEqual(
          JSON.parse(request.requestBody),
          { ai_decision_model: config },
          "preserves the custom header array"
        );
        return response({ success: true, probability: 0.99 });
      }
    );

    const result = await AiDecisionModel.create().testConfig(config);
    assert.true(result.success, "returns the test response");
  });
});
