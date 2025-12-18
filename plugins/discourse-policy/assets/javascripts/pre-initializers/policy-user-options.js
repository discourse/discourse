import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "policy-user-options",

  initialize(container) {
    withPluginApi((api) => {
      const { policy_enabled } = container.lookup("service:site-settings");

      if (policy_enabled) {
        api.addSaveableUserOption("policy_email_frequency", {
          page: "emails",
        });
      }
    });
  },
};
