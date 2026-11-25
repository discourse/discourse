import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "ai-post-image-caption-editor",
  initialize() {
    withPluginApi((api) => {
      const editor = api.container.lookup("service:post-image-caption-editor");

      api.registerValueTransformer("composer-image-descriptions-opener", () =>
        editor.enabled ? (args) => editor.open(args) : null
      );
    });
  },
};
