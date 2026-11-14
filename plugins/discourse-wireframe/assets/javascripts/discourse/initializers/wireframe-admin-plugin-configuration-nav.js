import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-wireframe";

export default {
  name: "wireframe-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "wand-magic-sparkles");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "wireframe.admin.designs.short_title",
          route: "adminPlugins.show.wireframe-designs",
          description: "wireframe.admin.designs.description",
        },
      ]);
    });
  },
};
