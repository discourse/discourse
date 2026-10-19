import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

export default class AiDecisionModel extends RestModel {
  createProperties() {
    return this.getProperties(
      "display_name",
      "name",
      "provider",
      "url",
      "ai_secret_id",
      "vision_enabled",
      "custom_headers"
    );
  }

  updateProperties() {
    return this.createProperties();
  }

  testConfig(config) {
    return ajax("/admin/plugins/discourse-ai/ai-decision-models/test.json", {
      type: "POST",
      contentType: "application/json",
      data: JSON.stringify({ ai_decision_model: config }),
    });
  }
}
