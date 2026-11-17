import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-captcha";

export default {
  name: "hcaptcha-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "hand");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "discourse_captcha.configuration_test.tab_title",
          route: "adminPlugins.show.discourse-captcha-test",
          description: "discourse_captcha.configuration_test.description",
        },
      ]);
    });
  },
};
