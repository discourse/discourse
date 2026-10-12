import { apiInitializer } from "discourse/lib/api";
import richEditorExtension from "../lib/ai-artifact-rich-editor-extension";

export default apiInitializer((api) => {
  if (api.container.lookup("service:site-settings").discourse_ai_enabled) {
    api.registerRichEditorExtension(richEditorExtension);
  }
});
