import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";

function initializeInternetExplorerDeprecation(api) {
  const siteSettings = api.container.lookup("site-settings:main");
  if (siteSettings.browser_deprecation_warning) {
    const { isIE11 } = api.container.lookup("capabilities:main");
    if (isIE11) {
      api.addGlobalNotice(
        I18n.t("discourse_unsupported_browser.deprecation_warning"),
        "browser-deprecation-warning",
        { dismissable: true, dismissDuration: moment.duration(1, "week") }
      );
    }
  }
}

export default {
  name: "discourse-unsupported-browser",

  initialize() {
    withPluginApi("0.8.37", initializeInternetExplorerDeprecation);
  }
};
