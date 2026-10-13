import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

export default class AiDecisionModel extends RestModel {
  createProperties() {
    return this.getProperties(
      "id",
      "display_name",
      "name",
      "provider",
      "url",
      "ai_secret_id",
      "vision_enabled"
    );
  }

  updateProperties() {
    const attrs = this.createProperties();
    attrs.id = this.id;

    return attrs;
  }

  async testConfig() {
    return await ajax(
      `/admin/plugins/discourse-ai/ai-decision-models/test.json`,
      {
        type: "POST",
        data: { ai_decision_model: this.createProperties() },
      }
    );
  }

  workingCopy() {
    const attrs = this.createProperties();
    return this.store.createRecord("ai-decision-model", attrs);
  }
}
