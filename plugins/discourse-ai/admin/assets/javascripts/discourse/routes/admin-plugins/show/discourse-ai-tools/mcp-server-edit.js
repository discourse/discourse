import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiToolsMcpServerEditRoute extends DiscourseRoute {
  model(params) {
    const toolsModel = this.modelFor("adminPlugins.show.discourse-ai-tools");
    const id = parseInt(params.id, 10);

    return toolsModel.mcpServers.content.find((server) => server.id === id);
  }

  setupController(controller) {
    super.setupController(...arguments);
    const toolsModel = this.modelFor("adminPlugins.show.discourse-ai-tools");
    controller.set("allMcpServers", toolsModel.mcpServers);
    controller.set("secrets", toolsModel.mcpServers.resultSetMeta.ai_secrets);
  }
}
