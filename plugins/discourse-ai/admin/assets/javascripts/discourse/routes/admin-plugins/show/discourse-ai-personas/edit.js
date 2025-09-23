import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiPersonasEdit extends DiscourseRoute {
  async model(params) {
    const allPersonas = this.modelFor(
      "adminPlugins.show.discourse-ai-personas"
    );
    const id = parseInt(params.id, 10);
    return allPersonas.findBy("id", id);
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allPersonas",
      this.modelFor("adminPlugins.show.discourse-ai-personas")
    );
  }
}
