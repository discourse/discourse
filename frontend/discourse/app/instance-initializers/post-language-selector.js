import { withPluginApi } from "discourse/lib/plugin-api";
import { applyValueTransformer } from "discourse/lib/transformer";
import { CREATE_TOPIC, EDIT, REPLY } from "discourse/models/composer";
import { i18n } from "discourse-i18n";

const ALLOWED_ACTIONS = [CREATE_TOPIC, EDIT, REPLY];

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");

    if (!siteSettings.content_localization_enabled) {
      return;
    }

    const languageNameLookup = owner.lookup("service:language-name-lookup");

    withPluginApi((api) => {
      api.onToolbarCreate((toolbar) => {
        const composerService = api.container.lookup("service:composer");
        const priority = applyValueTransformer(
          "post-language-selector-priority",
          "first",
          { action: composerService.model?.action }
        );

        const group = priority === "last" ? "extras" : "locale";

        if (priority !== "last") {
          toolbar.groups.unshift({ group: "locale", buttons: [] });
        }

        toolbar.addButton({
          id: "post-language-selector",
          group,
          icon: "language",
          title: "post.localizations.post_language_selector.title",
          className: "post-language-selector-trigger",
          condition: () => {
            const currentUser = api.getCurrentUser();
            return (
              currentUser &&
              ALLOWED_ACTIONS.includes(composerService.model?.action)
            );
          },
          popupMenu: {
            header: i18n("post.localizations.post_language_selector.header"),
            triggerLabel: () => {
              return composerService.model?.locale?.toUpperCase() || "";
            },
            action: (option) => {
              composerService.model.locale = option.locale;
            },
            options: () => {
              const locales =
                siteSettings.available_content_localization_locales.map(
                  ({ value }) => ({
                    name: value,
                    translatedLabel: languageNameLookup.getLanguageName(value),
                    locale: value,
                  })
                );

              locales.push({
                name: "none",
                label: "post.localizations.post_language_selector.none",
                locale: null,
              });

              return locales;
            },
          },
        });
      });
    });
  },
};
