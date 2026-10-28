import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiModelsRoute extends DiscourseRoute {
  async model() {
    const [llms, embeddings, decisionModels] = await Promise.all([
      this.store.findAll("ai-llm"),
      this.store.findAll("ai-embedding"),
      this.store.findAll("ai-decision-model"),
    ]);
    return { llms, embeddings, decisionModels };
  }
}
