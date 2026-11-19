import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "wireframe-admin-plugin-icon",

  initialize(container) {
    if (!container.lookup("service:current-user")?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon("discourse-wireframe", "wand-magic-sparkles");
    });
  },
};
