import { withPluginApi } from "discourse/lib/plugin-api";
import {
  addBlockDecorateCallback,
  addTagDecorateCallback,
} from "discourse/lib/to-markdown";
import applySpoiler from "discourse/plugins/spoiler-alert/lib/apply-spoiler";
import richEditorExtension from "discourse/plugins/spoiler-alert/lib/rich-editor-extension";

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
    label: "spoiler.title",
    action: (toolbarEvent) => {
      toolbarEvent.applySurround("[spoiler]", "[/spoiler]", "spoiler_text", {
        multiline: false,
        useBlockMode: true,
      });
    },
  });

  addTagDecorateCallback(function () {
    const { attributes } = this.element;

    if (/\bspoiled\b/.test(attributes.class)) {
      this.prefix = "[spoiler]";
      this.suffix = "[/spoiler]";
    }
  });

  addBlockDecorateCallback(function (text) {
    const { name, attributes } = this.element;

    if (name === "div" && /\bspoiled\b/.test(attributes.class)) {
      this.prefix = "[spoiler]\n";
      this.suffix = "\n[/spoiler]";
      return text.trim();
    }
  });

  api.registerRichEditorExtension(richEditorExtension);
}

export default {
  name: "spoiler-alert",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (siteSettings.spoiler_enabled) {
      withPluginApi("1.15.0", initializeSpoiler);
    }
  },
};
