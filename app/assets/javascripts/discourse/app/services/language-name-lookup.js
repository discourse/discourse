import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class LanguageNameLookup extends Service {
  @service siteSettings;

  getLanguageName(locale) {
    const name = this.siteSettings.available_locales.find(
      ({ value }) => value === locale
    )?.name;
    return name || locale;
  }
}
