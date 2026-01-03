import { getExtensions } from "discourse/lib/composer/rich-editor-extensions";
import { withPluginApi } from "discourse/lib/plugin-api";
import richEditorExtension from "../lib/rich-editor-extension";

export default {
  name: "discourse-math-rich-editor",
  initialize() {
    withPluginApi((api) => {
      if (getExtensions().includes(richEditorExtension)) {
        return;
      }

      api.registerRichEditorExtension(richEditorExtension);
    });
  },
};
