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
      "vision_enabled"
    );
  }

  updateProperties() {
    return this.createProperties();
  }

  async testConfig(config) {
    return await ajax(
      "/admin/plugins/discourse-ai/ai-decision-models/test.json",
      {
        type: "POST",
        data: { ai_decision_model: config },
      }
    );
  }
}
