import { registerEmoji } from "pretty-text/emoji";
import EmojiPicker from "discourse/components/emoji-picker";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
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
      api.registerChatComposerButton({
        label: "chat.emoji",
        id: "emoji",
        class: "chat-emoji-btn",
        icon: "discourse-emojis",
        position: "dropdown",
        displayed: owner.lookup("service:site").mobileView,
        action(context) {
          const didSelectEmoji = (emoji) => {
            const composer = owner.lookup(`service:chat-${context}-composer`);
            composer.textarea.addText(
              composer.textarea.getSelected(),
              `:${emoji}:`
            );
          };

          owner.lookup("service:menu").show(event.target, {
            identifier: "emoji-picker",
            groupIdentifier: "emoji-picker",
            component: EmojiPickerDetached,
            modalForMobile: true,
            data: {
              context: "chat",
              didSelectEmoji,
            },
          });
        },
      });

      api.onToolbarCreate((toolbar) => {
        toolbar.addButton({
          id: "emoji",
          group: "extras",
          icon: "discourse-emojis",
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
