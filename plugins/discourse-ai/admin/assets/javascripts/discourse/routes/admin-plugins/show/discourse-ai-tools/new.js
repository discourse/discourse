import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiToolsNewRoute extends DiscourseRoute {
  beforeModel(transition) {
    this.preset = transition.to.queryParams.presetId || "empty_tool";
  }

  async model() {
    return this.store.createRecord("ai-tool");
  }

  setupController(controller) {
    super.setupController(...arguments);
    const toolsModel = this.modelFor("adminPlugins.show.discourse-ai-tools");
    controller.set("allTools", toolsModel);
    controller.set("presets", toolsModel.resultSetMeta.presets);
    controller.set("llms", toolsModel.resultSetMeta.llms);
    controller.set("settings", toolsModel.resultSetMeta.settings);
    controller.set("selectedPreset", this.preset);
  }
}
