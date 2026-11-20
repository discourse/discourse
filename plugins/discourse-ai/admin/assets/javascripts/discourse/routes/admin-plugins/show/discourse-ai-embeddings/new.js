import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiEmbeddingsNew extends DiscourseRoute {
  queryParams = {
    preset: { refreshModel: true },
  };

  async model() {
    const record = this.store.createRecord("ai-embedding");
    record.provider_params = {};
    return record;
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allEmbeddings",
      this.modelFor("adminPlugins.show.discourse-ai-embeddings")
    );
    controller.set("preset", this.paramsFor(this.routeName).preset || null);
  }
}
