import { withPluginApi } from "discourse/lib/plugin-api";
import BlogAdminPluginActions from "../components/blog-admin-plugin-actions.gjs";

export default {
  name: "discourse-blog-admin-navigation",

  initialize(container) {
    if (!container.lookup("service:current-user")?.admin) {
      return;
    }
    withPluginApi((api) => {
      api.setAdminPluginIcon("blog", "pen-to-square");
      api.registerPluginHeaderActionComponent("blog", BlogAdminPluginActions);
      api.addAdminPluginConfigurationNav("blog", [
        {
          label: "blog.admin.themes",
          route: "adminPlugins.show.discourse-blog-themes",
          description: "blog.admin.themes_description",
        },
        {
          label: "blog.admin.identity_tab",
          route: "adminPlugins.show.discourse-blog-identity",
          description: "blog.admin.identity_description",
        },
      ]);
    });
  },
};
