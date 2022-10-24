import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";

function setupMessage(api) {
  const isSafari = navigator.vendor === "Apple Computer, Inc.";
  if (!isSafari) {
    return;
  }

  let safariMajorVersion = navigator.userAgent.match(/Version\/(\d+)\./)?.[1];
  safariMajorVersion = safariMajorVersion
    ? parseInt(safariMajorVersion, 10)
    : null;

  if (safariMajorVersion && safariMajorVersion <= 13) {
    api.addGlobalNotice(
      I18n.t("safari_13_warning"),
      "browser-deprecation-warning",
      { dismissable: true, dismissDuration: moment.duration(1, "week") }
    );
  }
}

export default {
  name: "safari-13-deprecation",

  initialize() {
    withPluginApi("0.8.37", setupMessage);
  },
};
