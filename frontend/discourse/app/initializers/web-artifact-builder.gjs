import { withPluginApi } from "discourse/lib/plugin-api";
import WebArtifactBuilder from "../components/modal/web-artifact-builder";

function initializeWebArtifactBuilder(api) {
  api.addComposerToolbarPopupMenuOption({
    action: (toolbarEvent) => {
      api.container.lookup("service:modal").show(WebArtifactBuilder, {
        model: { toolbarEvent },
      });
    },
    icon: "code",
    label: "web_artifact.composer_title",
    condition: () => {
      const siteSettings = api.container.lookup("service:site-settings");
      const currentUser = api.getCurrentUser();

      return (
        siteSettings.web_artifact_security !== "disabled" &&
        currentUser &&
        currentUser.can_create_web_artifact
      );
    },
  });
}

export default {
  name: "web-artifact-builder",
  initialize() {
    withPluginApi(initializeWebArtifactBuilder);
  },
};
