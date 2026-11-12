import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import EmbedMode from "discourse/lib/embed-mode";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  after: "inject-objects",

  initialize() {
    if (!EmbedMode.enabled) {
      return;
    }

    withPluginApi((api) => {
      api.registerValueTransformer("composer-force-editor-mode", () => {
        return USER_OPTION_COMPOSITION_MODES.rich;
      });
    });
  },
};
