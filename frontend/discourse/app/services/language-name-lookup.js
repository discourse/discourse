import Service, { service } from "discourse/lib/service";
import { disableImplicitInjections } from "discourse/lib/disable-implicit-injections";
import SiteSettingsService from "discourse/services/site-settings";

@disableImplicitInjections
export default class LanguageNameLookup extends Service {
  @service(() => SiteSettingsService) siteSettings;

  getLanguageName(locale) {
    const name = this.siteSettings.available_locales.find(
      ({ value }) => value === locale
    )?.name;
    return name || locale;
  }
}
