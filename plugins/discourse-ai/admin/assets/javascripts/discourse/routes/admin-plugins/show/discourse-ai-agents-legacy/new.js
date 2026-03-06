import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiAgentsLegacyNew extends DiscourseRoute {
  beforeModel() {
    this.replaceWith("adminPlugins.show.discourse-ai-agents.new");
  }
}
