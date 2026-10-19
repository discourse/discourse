import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize() {
    withPluginApi((api) => {
      api.registerCodeEditorLanguage(
        "liquid",
        () =>
          import("discourse/plugins/discourse-workflows/discourse/lib/liquid-language")
      );
    });
  },
};
