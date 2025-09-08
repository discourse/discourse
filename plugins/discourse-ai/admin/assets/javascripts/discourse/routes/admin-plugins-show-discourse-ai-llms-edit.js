import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiLlmsEdit extends DiscourseRoute {
  async model(params) {
    const id = parseInt(params.id, 10);

    if (id < 0) {
      // You shouldn't be able to access the edit page
      // if the model is seeded
      return this.router.transitionTo(
        "adminPlugins.show.discourse-ai-llms.index"
      );
    }

    const allLlms = this.modelFor("adminPlugins.show.discourse-ai-llms");
    const record = allLlms.findBy("id", id);
    record.provider_params = record.provider_params || {};
    return record;
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allLlms",
      this.modelFor("adminPlugins.show.discourse-ai-llms")
    );
  }
}
