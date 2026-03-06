import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiAgentsLegacyEdit extends DiscourseRoute {
  model(params) {
    this.replaceWith("adminPlugins.show.discourse-ai-agents.edit", params.id);
  }
}
