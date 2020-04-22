import { withPluginApi } from "discourse/lib/plugin-api";

function initializeInternetExplorerDeprecation(api) {
  const siteSettings = api.container.lookup("site-settings:main");
  if (siteSettings.discourse_internet_explorer_deprecation_warning) {
    const { isIE11 } = api.container.lookup("capabilities:main");
    if (isIE11) {
      api.addGlobalNotice(
        I18n.t("discourse_internet_explorer.deprecation_warning"),
        "deprecate-internet-explorer",
        { dismissable: true, dismissDuration: moment.duration(1, "week") }
      );
    }
  }
}

export default {
  name: "discourse-internet-explorer",

  initialize() {
    withPluginApi("0.8.37", initializeInternetExplorerDeprecation);
  }
};
