import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiEmbeddingsEdit extends DiscourseRoute {
  async model(params) {
    const allEmbeddings = this.modelFor(
      "adminPlugins.show.discourse-ai-embeddings"
    );
    const id = parseInt(params.id, 10);
    const record = allEmbeddings.findBy("id", id);
    record.provider_params = record.provider_params || {};
    return record;
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allEmbeddings",
      this.modelFor("adminPlugins.show.discourse-ai-embeddings")
    );
  }
}
