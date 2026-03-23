import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-workflows";

export default {
  name: "discourse-workflows-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "discourse_workflows.title",
          route: "adminPlugins.show.discourse-workflows.index",
          currentWhen:
            "adminPlugins.show.discourse-workflows.index adminPlugins.show.discourse-workflows.new adminPlugins.show.discourse-workflows.show.index adminPlugins.show.discourse-workflows.show.executions.index adminPlugins.show.discourse-workflows.show.executions.show adminPlugins.show.discourse-workflows.show.settings",
        },
        {
          label: "discourse_workflows.variables.title",
          route: "adminPlugins.show.discourse-workflows.variables",
        },
        {
          label: "discourse_workflows.data_tables.title",
          route: "adminPlugins.show.discourse-workflows.data-tables",
        },
        {
          label: "discourse_workflows.executions.title",
          route: "adminPlugins.show.discourse-workflows.executions",
        },
        {
          label: "discourse_workflows.templates.title",
          route: "adminPlugins.show.discourse-workflows.templates",
        },
      ]);
    });
  },
};
