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
        toolbar.groups.unshift({ group: "locale", buttons: [] });
        toolbar.addButton({
          id: "post-language-selector",
          group: "locale",
          icon: "language",
          title: "post.localizations.post_language_selector.title",
          className: "post-language-selector-trigger",
          condition: () => {
            const composer = api.container.lookup("service:composer");
            const currentUser = api.getCurrentUser();
            if (
              !currentUser ||
              !ALLOWED_ACTIONS.includes(composer.model?.action)
            ) {
              return false;
            }
            return applyValueTransformer(
              "post-language-selector-should-show",
              true,
              { action: composer.model?.action }
            );
          },
          popupMenu: {
            header: i18n("post.localizations.post_language_selector.header"),
            triggerLabel: () => {
              const composer = api.container.lookup("service:composer");
              return composer.model?.locale?.toUpperCase() || "";
            },
            action: (option) => {
              const composer = api.container.lookup("service:composer");
              composer.model.locale = option.locale;
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
