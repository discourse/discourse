import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiAgentsLegacy extends DiscourseRoute {
  beforeModel(transition) {
    const url = transition.intent?.url?.replace("ai-personas", "ai-agents");
    if (url) {
      this.replaceWith(url);
    } else {
      this.replaceWith("adminPlugins.show.discourse-ai-agents");
    }
  }
}
