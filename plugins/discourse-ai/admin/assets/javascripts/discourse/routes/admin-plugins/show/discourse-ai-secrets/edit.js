import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiSecretsEdit extends DiscourseRoute {
  async model(params) {
    return this.store.find("ai-secret", params.id);
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allSecrets",
      this.modelFor("adminPlugins.show.discourse-ai-secrets")
    );
  }
}
