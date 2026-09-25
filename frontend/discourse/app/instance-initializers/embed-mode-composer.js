import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import { withPluginApi } from "discourse/lib/core-api";
import EmbedMode from "discourse/lib/embed-mode";

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
