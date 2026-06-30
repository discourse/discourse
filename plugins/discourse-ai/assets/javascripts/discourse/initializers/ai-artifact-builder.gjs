import { withPluginApi } from "discourse/lib/plugin-api";
import AiArtifactBuilder from "../components/modal/ai-artifact-builder";

function initializeAiArtifactBuilder(api) {
  api.addComposerToolbarPopupMenuOption({
    action: (toolbarEvent) => {
      api.container.lookup("service:modal").show(AiArtifactBuilder, {
        model: { toolbarEvent },
      });
    },
    icon: "code",
    label: "discourse_ai.ai_artifact.composer.insert_title",
    name: "ai-artifact",
    condition: () => api.getCurrentUser()?.can_create_ai_artifact,
  });
}

export default {
  name: "ai-artifact-builder",
  initialize() {
    withPluginApi(initializeAiArtifactBuilder);
  },
};
