import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-ai-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser || !currentUser.admin) {
      return;
    }

    withPluginApi("1.1.0", (api) => {
      api.addAdminPluginConfigurationNav("discourse-ai", [
        {
          label: "discourse_ai.features.short_title",
          route: "adminPlugins.show.discourse-ai-features",
          description: "discourse_ai.features.description",
        },
        {
          label: "discourse_ai.usage.short_title",
          route: "adminPlugins.show.discourse-ai-usage",
          description: "discourse_ai.usage.subheader_description",
        },
        {
          label: "discourse_ai.llms.short_title",
          route: "adminPlugins.show.discourse-ai-llms",
          description: "discourse_ai.llms.preconfigured.description",
        },
        {
          label: "discourse_ai.ai_persona.short_title",
          route: "adminPlugins.show.discourse-ai-personas",
          description: "discourse_ai.ai_persona.persona_description",
        },
        {
          label: "discourse_ai.embeddings.short_title",
          route: "adminPlugins.show.discourse-ai-embeddings",
          description: "discourse_ai.embeddings.description",
        },
        {
          label: "discourse_ai.tools.short_title",
          route: "adminPlugins.show.discourse-ai-tools",
          description: "discourse_ai.tools.subheader_description",
        },
        {
          label: "discourse_ai.spam.short_title",
          route: "adminPlugins.show.discourse-ai-spam",
          description: "discourse_ai.spam.spam_description",
        },
      ]);
    });
  },
};
