import Service, { service } from "@ember/service";

export default class PostLocalization extends Service {
  @service siteSettings;
  @service composer;

  // TODO: replace and make use of this getter in language picker and translation-editor
  get availableLocales() {
    const allAvailableLocales = JSON.parse(this.siteSettings.available_locales);
    const supportedLocales =
      this.siteSettings.experimental_content_localization_supported_locales.split(
        "|"
      );

    if (!supportedLocales.includes(this.siteSettings.default_locale)) {
      supportedLocales.push(this.siteSettings.default_locale);
    }

    const filtered = allAvailableLocales.filter((locale) => {
      return supportedLocales.includes(locale.value);
    });

    return filtered;
  }
}
