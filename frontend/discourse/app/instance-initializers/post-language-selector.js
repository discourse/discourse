import { composerState } from "discourse/lib/composer/state";
import { withPluginApi } from "discourse/lib/core-api";
import { lookup } from "discourse/lib/service";
import { applyValueTransformer } from "discourse/lib/transformer";
import { CREATE_TOPIC, EDIT, REPLY } from "discourse/models/composer";
import LanguageNameLookupService from "discourse/services/language-name-lookup";
import SiteSettingsService from "discourse/services/site-settings";
import { i18n } from "discourse-i18n";

const ALLOWED_ACTIONS = [CREATE_TOPIC, EDIT, REPLY];

export default {
  initialize(owner) {
    const siteSettings = lookup(owner, SiteSettingsService);

    if (!siteSettings.content_localization_enabled) {
      return;
    }

    const languageNameLookup = lookup(owner, LanguageNameLookupService);

    withPluginApi((api) => {
      api.onToolbarCreate((toolbar) => {
        // The composer service exists whenever a composer toolbar does.
        const composerService = composerState.service;
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
