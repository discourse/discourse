import I18n from "discourse-i18n";

export default {
  after: "inject-objects",

  isVerboseLocalizationEnabled(owner) {
    const siteSettings = owner.lookup("service:site-settings");
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
