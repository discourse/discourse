import { registerEmoji } from "pretty-text/emoji";
import ComposerEmojiPicker from "discourse/components/composer-emoji-picker";
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
          group: "extras",
          action: (emoji) => toolbar.context.send("emojiSelected", emoji),
          title: "composer.emoji",
          className: "emoji insert-emoji",
          component: ComposerEmojiPicker,
        });
      });
    });

    (PreloadStore.get("customEmoji") || []).forEach((emoji) =>
      registerEmoji(emoji.name, emoji.url, emoji.group)
    );
  },
};
