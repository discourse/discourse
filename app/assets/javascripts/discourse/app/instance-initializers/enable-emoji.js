import PreloadStore from "discourse/lib/preload-store";
import { registerEmoji } from "pretty-text/emoji";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    if (!siteSettings.enable_emoji) {
      return;
    }

    withPluginApi("0.1", (api) => {
      api.onToolbarCreate((toolbar) => {
        toolbar.addButton({
          id: "emoji",
          group: "extras",
          icon: "far-smile",
          action: () => toolbar.context.send("emoji"),
          title: "composer.emoji",
          className: "emoji insert-emoji",
        });
      });
    });

    (PreloadStore.get("customEmoji") || []).forEach((emoji) =>
      registerEmoji(emoji.name, emoji.url, emoji.group)
    );
  },
};
