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

    // Merge any overrides into our object
    for (const [locale, overrides] of Object.entries(I18n._overrides || {})) {
      for (const [key, value] of Object.entries(overrides)) {
        const segs = key.replace(/^admin_js\./, "js.").split(".");
        let node = I18n.translations[locale] || {};

        for (let i = 0; i < segs.length - 1; i++) {
          if (!(segs[i] in node)) {
            node[segs[i]] = {};
          }
          node = node[segs[i]];
        }

        if (typeof node === "object") {
          node[segs[segs.length - 1]] = value;
        }
      }

      delete I18n._overrides;
    }
  },
};
