import { isTesting } from "discourse-common/config/environment";
import { getAndClearThemeErrors } from "discourse/app";
import PreloadStore from "discourse/lib/preload-store";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";

export default {
  name: "theme-errors-handler",
  after: "inject-discourse-objects",

  initialize(container) {
    const currentUser = container.lookup("current-user:main");
    if (isTesting()) {
      return;
    }
    renderErrorNotices(currentUser);
    document.addEventListener("discourse-theme-error", () =>
      renderErrorNotices(currentUser)
    );
  },
};

function reportToLogster(name, error) {
  const data = {
    message: `${name} theme/component is throwing errors`,
    stacktrace: error.stack,
  };

  Ember.$.ajax(getURL("/logs/report_js_error"), {
    data,
    type: "POST",
  });
}

function renderErrorNotices(currentUser) {
  getAndClearThemeErrors().forEach(([themeId, error]) => {
    const name =
      PreloadStore.get("activatedThemes")[themeId] || `(theme-id: ${themeId})`;
    /* eslint-disable-next-line no-console */
    console.error(`An error occurred in the "${name}" theme/component:`, error);
    reportToLogster(name, error);
    if (!currentUser || !currentUser.admin) {
      return;
    }
    const path = getURL("/admin/customize/themes");
    const message = I18n.t("themes.broken_theme_alert", {
      theme: name,
      path: `<a href="${path}">${path}</a>`,
    });
    const alertDiv = document.createElement("div");
    alertDiv.classList.add("broken-theme-alert");
    alertDiv.innerHTML = `⚠️ ${message}`;
    document.body.prepend(alertDiv);
  });
}
