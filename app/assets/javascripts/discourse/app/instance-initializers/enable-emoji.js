import { registerEmoji } from "pretty-text/emoji";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
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
          icon: "discourse-emojis",
          sendAction: () => {
            const menu = api.container.lookup("service:menu");
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

    (PreloadStore.get("customEmoji") || []).forEach((emoji) =>
      registerEmoji(emoji.name, emoji.url, emoji.group)
    );
  },
};
