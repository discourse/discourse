import { withPluginApi } from "discourse/lib/plugin-api";
import PolicyBuilder from "../components/modal/policy-builder";

function initializePolicyBuilder(api, container) {
  const currentUser = api.getCurrentUser();
  const siteSettings = container.lookup("service:site-settings");
  const modal = container.lookup("service:modal");

  if (currentUser) {
    api.addComposerToolbarPopupMenuOption({
      label: "discourse_policy.builder.attach",
      icon: "file-signature",
      group: "insertions",
      action: (toolbarEvent) => {
        modal.show(PolicyBuilder, {
          model: {
            insertMode: true,
            post: null,
            toolbarEvent,
          },
        });
      },
      condition: () =>
        !siteSettings.policy_restrict_to_staff_posts || currentUser.staff,
    });
  }
}

export default {
  name: "add-discourse-policy-builder",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.policy_enabled) {
      withPluginApi("1.13.0", (api) => initializePolicyBuilder(api, container));
    }
  },
};
