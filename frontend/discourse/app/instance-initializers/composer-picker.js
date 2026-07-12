import ComposerPickerDetached from "discourse/components/composer-picker/detached";
import { composerPickerTabs } from "discourse/lib/composer-picker";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");

    withPluginApi((api) => {
      api.onToolbarCreate((toolbar) => {
        // Gated behind the upcoming change; the legacy emoji/GIF buttons
        // register instead when it is off.
        if (!siteSettings.enable_unified_composer_picker) {
          return;
        }

        // Computed per toolbar (not at initialize) so tabs registered by
        // plugin initializers are visible and GIF is scoped to real composers.
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

            menu.show(document.querySelector(".insert-composer-emoji"), {
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
          title: "composer.emoji",
          className: "emoji insert-composer-emoji",
        });
      });
    });
  },
};
