import { withPluginApi } from "discourse/lib/plugin-api";
import applySpoiler from "discourse/plugins/spoiler-alert/lib/apply-spoiler";
import richEditorExtension from "../lib/rich-editor-extension";

function spoil(element) {
  element.querySelectorAll(".spoiler").forEach((spoiler) => {
    spoiler.classList.remove("spoiler");
    spoiler.classList.add("spoiled");
    applySpoiler(spoiler);
  });
}

export function initializeSpoiler(api) {
  api.decorateCookedElement(spoil, { id: "spoiler-alert" });

  api.addComposerToolbarPopupMenuOption({
    icon: "wand-magic",
    active: ({ state }) => state.inSpoiler,
    showActiveIcon: true,
    label: "spoiler.title",
    action: (toolbarEvent) => {
      if (toolbarEvent.commands) {
        toolbarEvent.commands.toggleSpoiler();
      } else {
        toolbarEvent.applySurround("[spoiler]", "[/spoiler]", "spoiler_text", {
          multiline: false,
          useBlockMode: true,
        });
      }
    },
  });

  api.registerRichEditorExtension(richEditorExtension);
}

export default {
  name: "spoiler-alert",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (siteSettings.spoiler_enabled) {
      withPluginApi(initializeSpoiler);
    }
  },
};
