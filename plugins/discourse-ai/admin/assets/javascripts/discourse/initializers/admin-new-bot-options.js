import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  if (!api.getCurrentUser()?.admin) {
    return;
  }

  api.registerValueTransformer("admin-new-bot-options", ({ value }) => [
    ...value,
    {
      id: "ai-agent",
      icon: "discourse-sparkles",
      label: "discourse_ai.ai_agent.new_bot_option.label",
      description: "discourse_ai.ai_agent.new_bot_option.description",
      route: "adminPlugins.show.discourse-ai-agents.new",
      routeModels: ["discourse-ai"],
      queryParams: { source: "bots" },
    },
  ]);
});
