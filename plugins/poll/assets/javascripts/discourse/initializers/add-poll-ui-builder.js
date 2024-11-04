import { withPluginApi } from "discourse/lib/plugin-api";
import richEditorExtension from "../../lib/rich-editor-extension";
import PollUiBuilder from "../components/modal/poll-ui-builder";

function initializePollUIBuilder(api) {
  api.addComposerToolbarPopupMenuOption({
    action: (toolbarEvent) => {
      api.container.lookup("service:modal").show(PollUiBuilder, {
        model: { toolbarEvent },
      });
    },
    icon: "chart-bar",
    label: "poll.ui_builder.title",
    condition: (composer) => {
      const siteSettings = api.container.lookup("service:site-settings");
      const currentUser = api.getCurrentUser();

      return (
        siteSettings.poll_enabled &&
        (composer.model.topic?.pm_with_non_human_user ||
          (currentUser && (currentUser.staff || currentUser.can_create_poll)))
      );
    },
  });

  api.registerRichEditorExtension(richEditorExtension);
}

export default {
  name: "add-poll-ui-builder",

  initialize() {
    withPluginApi("1.14.0", initializePollUIBuilder);
  },
};
