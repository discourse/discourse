import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiAgentsLegacy extends DiscourseRoute {
  beforeModel() {
    this.replaceWith("adminPlugins.show.discourse-ai-agents");
  }
}
