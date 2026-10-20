import ComposerPickerDetached from "discourse/components/composer-picker/detached";
import { composerPickerTabs } from "discourse/lib/composer-picker";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");

    withPluginApi((api) => {
      api.onToolbarCreate((toolbar) => {
        if (!siteSettings.enable_composer_picker_and_rich_chat) {
          return;
        }

        // per toolbar, so tabs registered by later initializers are included
        const composerEvents = !!toolbar.context?.composerEvents;
        const tabs = composerPickerTabs(owner, { composerEvents });

        if (!tabs.length) {
          return;
        }

        toolbar.addButton({
          id: "emoji",
          group: "extras",
          icon: tabs[0].icon,
          sendAction: () => {
            const menu = api.container.lookup("service:menu");

            // every editor on the page has this button, and a redesigned
            // composer renders its toolbar outside the editor element
            const trigger =
              document.activeElement?.closest(".insert-composer-emoji") ??
              toolbar.context?.element?.querySelector(
                ".insert-composer-emoji"
              ) ??
              document.querySelector(".insert-composer-emoji");

            menu.show(trigger, {
              identifier: "composer-picker",
              groupIdentifier: "composer-picker",
              component: ComposerPickerDetached,
              modalForMobile: true,
              data: {
                context: "topic",
                composerEvents,
                onSelect: (value, tab) => {
                  const { textManipulation } = toolbar.context;
                  if (tab.id === "emoji") {
                    textManipulation.emojiSelected(value);
                  } else {
                    textManipulation.insertText(value);
                  }
                },
              },
            });
          },
          title: tabs.length > 1 ? "composer_picker.label" : tabs[0].title,
          className: "emoji insert-composer-emoji",
        });
      });
    });
  },
};
