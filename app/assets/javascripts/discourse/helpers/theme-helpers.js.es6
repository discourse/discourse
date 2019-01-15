import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("theme-i18n", (themeId, key, params) => {
  return I18n.t(`theme_translations.${themeId}.${key}`, params);
});

registerUnbound(
  "theme-prefix",
  (themeId, key) => `theme_translations.${themeId}.${key}`
);

registerUnbound("theme-setting", (themeId, key) =>
  Discourse.__container__
    .lookup("service:theme-settings")
    .getSetting(themeId, key)
);
