import { apiInitializer } from "discourse/lib/api";
import { getExtensions } from "discourse/lib/composer/rich-editor-extensions";
import richEditorExtension from "../lib/rich-editor-extension.js";

export default apiInitializer((api) => {
  if (getExtensions().includes(richEditorExtension)) {
    return;
  }

  api.registerRichEditorExtension(richEditorExtension);
});
