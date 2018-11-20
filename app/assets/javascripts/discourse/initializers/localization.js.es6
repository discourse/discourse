import PreloadStore from "preload-store";

export default {
  name: "localization",
  after: "inject-objects",

  isVerboseLocalizationEnabled(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.verbose_localization) return true;

    try {
      return sessionStorage && sessionStorage.getItem("verbose_localization");
    } catch (e) {
      return false;
    }
  },

  initialize(container) {
    if (this.isVerboseLocalizationEnabled(container)) {
      I18n.enableVerboseLocalization();
    }

    // Merge any overrides into our object
    const overrides = PreloadStore.get("translationOverrides") || {};
    Object.keys(overrides).forEach(k => {
      const v = overrides[k];

      // Special case: Message format keys are functions
      if (/_MF$/.test(k)) {
        k = k.replace(/^[a-z_]*js\./, "");
        I18n._compiledMFs[k] = new Function(
          "transKey",
          `return (${v})(transKey);`
        );
        return;
      }

      k = k.replace("admin_js", "js");

      const segs = k.split(".");

      let node = I18n.translations[I18n.locale];
      let i = 0;

      for (; i < segs.length - 1; i++) {
        if (!(segs[i] in node)) node[segs[i]] = {};
        node = node[segs[i]];
      }

      if (typeof node === "object") {
        node[segs[segs.length - 1]] = v;
      }
    });
  }
};
