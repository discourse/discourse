import { lookup } from "discourse/lib/service";
import { withPluginApi } from "discourse/lib/core-api";
import PreloadStore from "discourse/lib/preload-store";
import SiteSettingsService from "discourse/services/site-settings";
import MenuService from "discourse/float-kit/services/menu";

export default {
  initialize(owner) {
    const siteSettings = lookup(owner, SiteSettingsService);

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
            const menu = lookup(api.container, MenuService);
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
