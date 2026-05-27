import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiToolsMcpServerNewRoute extends DiscourseRoute {
  async model() {
    return this.store.createRecord("ai-mcp-server");
  }

  setupController(controller) {
    super.setupController(...arguments);
    const toolsModel = this.modelFor("adminPlugins.show.discourse-ai-tools");
    controller.set("allMcpServers", toolsModel.mcpServers);
    controller.set("secrets", toolsModel.mcpServers.resultSetMeta.ai_secrets);
  }
}
