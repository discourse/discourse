import { registerEmoji } from "pretty-text/emoji";
import EmojiPicker from "discourse/components/emoji-picker";
import { withPluginApi } from "discourse/lib/plugin-api";
import PreloadStore from "discourse/lib/preload-store";

const EmojiPickerWrapper = <template>
  <EmojiPicker
    @btnClass={{@button.className}}
    @didSelectEmoji={{@button.action}}
  />
</template>;

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
          icon: "far-face-smile",
          action: (emoji) => {
            toolbar.context.textManipulation.emojiSelected(emoji);
          },
          title: "composer.emoji",
          className: "emoji insert-emoji",
          component: EmojiPickerWrapper,
        });
      });
    });

    (PreloadStore.get("customEmoji") || []).forEach((emoji) =>
      registerEmoji(emoji.name, emoji.url, emoji.group)
    );
  },
};
