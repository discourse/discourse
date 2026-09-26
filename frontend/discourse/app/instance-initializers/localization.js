import { lookup } from "discourse/lib/service";
import I18n from "discourse-i18n";
import SiteSettingsService from "discourse/services/site-settings";

export default {
  after: "inject-objects",

  isVerboseLocalizationEnabled(owner) {
    const siteSettings = lookup(owner, SiteSettingsService);
    if (siteSettings.verbose_localization) {
      return true;
    }

    try {
      return sessionStorage && sessionStorage.getItem("verbose_localization");
    } catch {
      return false;
    }
  },

  initialize(owner) {
    if (this.isVerboseLocalizationEnabled(owner)) {
      I18n.enableVerboseLocalization();
    }
  },
};
