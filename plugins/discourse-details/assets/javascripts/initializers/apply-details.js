import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import richEditorExtension from "../lib/rich-editor-extension.js";

function initializeDetails(api) {
  api.addComposerToolbarPopupMenuOption({
    action: function (toolbarEvent) {
      toolbarEvent.applySurround(
        "\n" + `[details="${i18n("composer.details_title")}"]` + "\n",
        "\n[/details]\n",
        "details_text",
        { multiline: false }
      );
    },
    icon: "angle-right",
    label: "details.title",
    name: "details",
    shortcut: "Shift+D",
  });

  api.addComposerToolbarPopupMenuOption({
    action() {
      const placeholder = i18n("composer.ai_content.placeholder");
      const summary = placeholder.replace(/"/g, "“");
      api.container
        .lookup("service:app-events")
        .trigger(
          "composer:insert-block",
          `[details="${summary}" ai=true]\n${placeholder}\n[/details]`
        );
    },
    condition: (composer) => composer.siteSettings.details_enabled,
    icon: "angle-right",
    label: "composer.ai_content.details",
    menu: "ai-content",
    name: "ai-content-details",
  });

  api.registerRichEditorExtension(richEditorExtension);
}

export default {
  name: "apply-details",

  initialize() {
    withPluginApi(initializeDetails);
  },
};
