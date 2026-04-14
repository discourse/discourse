import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiToolsNewRoute extends DiscourseRoute {
  queryParams = {
    presetId: { refreshModel: false },
  };

  beforeModel(transition) {
    this.preset = transition.to.queryParams.presetId || "empty_tool";
  }

  async model() {
    return this.store.createRecord("ai-tool");
  }

  setupController(controller) {
    super.setupController(...arguments);
    const toolsModel = this.modelFor("adminPlugins.show.discourse-ai-tools");
    controller.set("allTools", toolsModel.tools);
    controller.set("presets", toolsModel.tools.resultSetMeta.presets);
    controller.set("llms", toolsModel.tools.resultSetMeta.llms);
    controller.set("secrets", toolsModel.tools.resultSetMeta.ai_secrets);
    controller.set("settings", toolsModel.tools.resultSetMeta.settings);
    controller.set("selectedPreset", this.preset);
  }
}
