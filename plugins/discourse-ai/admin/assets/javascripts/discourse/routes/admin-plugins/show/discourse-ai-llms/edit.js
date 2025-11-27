import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiLlmsEdit extends DiscourseRoute {
  async model(params) {
    const id = parseInt(params.id, 10);
    const allLlms = this.modelFor("adminPlugins.show.discourse-ai-llms");
    const record = allLlms.content.find((item) => item.id === id);
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
