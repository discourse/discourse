import { withPluginApi } from "discourse/lib/core-api";
import PreloadStore from "discourse/lib/preload-store";

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");

    if (!siteSettings.enable_emoji) {
      return;
    }

    withPluginApi((api) => {
      api.onToolbarCreate((toolbar) => {
        toolbar.addButton({
          id: "emoji",
          group: "extras",
          icon: "far-face-smile",
          sendAction: async () => {
            const menu = api.container.lookup("service:menu");
            const { default: EmojiPickerDetached } =
              await import("discourse/components/emoji-picker/detached");
            menu.show(document.querySelector(".insert-composer-emoji"), {
              identifier: "emoji-picker",
              groupIdentifier: "emoji-picker",
              component: EmojiPickerDetached,
              modalForMobile: true,
              data: {
                didSelectEmoji: (emoji) => {
                  toolbar.context.textManipulation.emojiSelected(emoji);
                },
              },
            });
          },
          title: "composer.emoji",
          className: "emoji insert-composer-emoji",
        });
      });
    });

    const customEmoji = PreloadStore.get("customEmoji") || [];

    if (customEmoji.length) {
      import("pretty-text/emoji").then(({ registerEmoji }) =>
        customEmoji.forEach((emoji) =>
          registerEmoji(emoji.name, emoji.url, emoji.group)
        )
      );
    }
  },
};
