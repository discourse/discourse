import $ from "jquery";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import richEditorExtension from "../lib/rich-editor-extension";

function initializeDetails(api) {
  api.decorateCooked(($elem) => $("details", $elem), {
    id: "discourse-details",
  });

  api.addComposerToolbarPopupMenuOption({
    action: function (toolbarEvent) {
      toolbarEvent.applySurround(
        "\n" + `[details="${i18n("composer.details_title")}"]` + "\n",
        "\n[/details]\n",
        "details_text",
        { multiline: false }
      );
    },
    icon: "caret-right",
    label: "details.title",
  });

  api.registerRichEditorExtension(richEditorExtension);
}

export default {
  name: "apply-details",

  initialize() {
    withPluginApi("1.14.0", initializeDetails);
  },
};
