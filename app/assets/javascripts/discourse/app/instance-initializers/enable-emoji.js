import { registerEmoji } from "pretty-text/emoji";
import { withPluginApi } from "discourse/lib/plugin-api";
import PreloadStore from "discourse/lib/preload-store";

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
          group: "insertions",
          icon: "face-smile",
          action: () => toolbar.context.send("emoji"),
          title: "composer.emoji",
          className: "emoji insert-emoji",
          unshift: true,
        });
      });
    });

    (PreloadStore.get("customEmoji") || []).forEach((emoji) =>
      registerEmoji(emoji.name, emoji.url, emoji.group)
    );
  },
};
