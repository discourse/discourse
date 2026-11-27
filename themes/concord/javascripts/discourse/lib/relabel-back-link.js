import I18n from "discourse-i18n";

const THEME_ID = themePrefix("").split(".")[1];

/**
 * Core's "Back to Forum" link, atop the admin and Discourse AI sidebars,
 * leads back to the channel list, where a forum is one kind of channel among
 * several. Only where the theme has its own wording for the language, so
 * other languages keep core's.
 */
export default function relabelBackLink() {
  const translations = I18n.translations[I18n.currentLocale()]?.js;
  const label = translations?.theme_translations?.[THEME_ID]?.back_to_channels;

  if (label && translations.sidebar) {
    translations.sidebar.back_to_forum = label;
  }
}
