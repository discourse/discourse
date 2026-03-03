import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiSecretsNew extends DiscourseRoute {
  async model() {
    return this.store.createRecord("ai-secret");
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allSecrets",
      this.modelFor("adminPlugins.show.discourse-ai-secrets")
    );
  }
}
