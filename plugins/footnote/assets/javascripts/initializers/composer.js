import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import richEditorExtension from "../lib/rich-editor-extension";

export default {
  name: "footnotes-composer",

  initialize() {
    withPluginApi((api) => {
      api.registerRichEditorExtension(richEditorExtension);

      api.addComposerToolbarPopupMenuOption({
        action(event) {
          event.addText(`^[${i18n("footnote.title")}]`);
        },
        group: "insertions",
        icon: "asterisk",
        label: "footnote.add",
      });
    });
  },
};
