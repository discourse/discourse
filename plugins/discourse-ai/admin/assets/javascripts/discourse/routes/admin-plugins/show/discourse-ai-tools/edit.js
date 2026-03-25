import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiToolsEditRoute extends DiscourseRoute {
  async model(params) {
    const allTools = this.modelFor("adminPlugins.show.discourse-ai-tools");
    const id = parseInt(params.id, 10);

    return allTools.tools.content.find((tool) => tool.id === id);
  }

  setupController(controller) {
    super.setupController(...arguments);
    const toolsModel = this.modelFor("adminPlugins.show.discourse-ai-tools");

    controller.set("allTools", toolsModel.tools);
    controller.set("presets", toolsModel.tools.resultSetMeta.presets);
    controller.set("llms", toolsModel.tools.resultSetMeta.llms);
    controller.set("secrets", toolsModel.tools.resultSetMeta.ai_secrets);
    controller.set("settings", toolsModel.tools.resultSetMeta.settings);
  }
}
