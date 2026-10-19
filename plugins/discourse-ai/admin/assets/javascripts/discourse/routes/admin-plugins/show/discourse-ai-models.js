import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiModelsRoute extends DiscourseRoute {
  @service siteSettings;

  async model() {
    const [llms, embeddings, decisionModels] = await Promise.all([
      this.store.findAll("ai-llm"),
      this.store.findAll("ai-embedding"),
      this.siteSettings.enable_discourse_workflows
        ? this.store.findAll("ai-decision-model")
        : null,
    ]);
    return { llms, embeddings, decisionModels };
  }
}
