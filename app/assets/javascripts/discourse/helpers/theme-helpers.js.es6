import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound(
  "theme-i18n",
  (themeId, key, params) => {
    return I18n.t(`theme_translations.${themeId}.${key}`, params);
  },
  2
);

registerUnbound(
  "theme-prefix",
  (themeId, key) => `theme_translations.${themeId}.${key}`,
  2
);

registerUnbound(
  "theme-setting",
  (themeId, key) =>
    Discourse.__container__
      .lookup("service:theme-settings")
      .getSetting(themeId, key),
  2
);
