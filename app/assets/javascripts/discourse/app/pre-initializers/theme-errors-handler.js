import { isTesting } from "discourse-common/config/environment";
import { getAndClearUnhandledThemeErrors } from "discourse/app";
import PreloadStore from "discourse/lib/preload-store";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";
import { bind } from "discourse-common/utils/decorators";

const showingErrors = new Set();

export default {
  name: "theme-errors-handler",
  after: "inject-discourse-objects",

  initialize(container) {
    if (isTesting()) {
      return;
    }

    this.currentUser = container.lookup("current-user:main");

    getAndClearUnhandledThemeErrors().forEach((e) => {
      reportThemeError(this.currentUser, e);
    });

    document.addEventListener("discourse-error", this.handleDiscourseError);
  },

  teardown() {
    document.removeEventListener("discourse-error", this.handleDiscourseError);
    delete this.currentUser;
  },

  @bind
  handleDiscourseError(e) {
    if (e.detail?.themeId) {
      reportThemeError(this.currentUser, e);
    } else {
      reportGenericError(this.currentUser, e);
    }
    e.preventDefault(); // Mark as handled
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

function reportThemeError(currentUser, e) {
  const { themeId, error } = e.detail;

  const name =
    PreloadStore.get("activatedThemes")[themeId] || `(theme-id: ${themeId})`;
  /* eslint-disable-next-line no-console */
  console.error(`An error occurred in the "${name}" theme/component:`, error);
  reportToLogster(name, error);

  const path = getURL("/admin/customize/themes");
  const message = I18n.t("themes.broken_theme_alert", {
    theme: name,
    path: `<a href="${path}">${path}</a>`,
  });
  displayErrorNotice(currentUser, message);
}

function reportGenericError(currentUser, e) {
  const { messageKey, error } = e.detail;

  /* eslint-disable-next-line no-console */
  console.error(error);

  if (messageKey && !showingErrors.has(messageKey)) {
    showingErrors.add(messageKey);
    displayErrorNotice(currentUser, I18n.t(messageKey));
  }
}

function displayErrorNotice(currentUser, message) {
  if (!currentUser?.admin) {
    return;
  }

  const alertDiv = document.createElement("div");
  alertDiv.classList.add("broken-theme-alert");
  alertDiv.innerHTML = `⚠️ ${message}`;
  document.body.prepend(alertDiv);
}
