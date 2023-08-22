import { isTesting } from "discourse-common/config/environment";
import { getAndClearUnhandledThemeErrors } from "discourse/app";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";
import { bind } from "discourse-common/utils/decorators";
import { escape } from "pretty-text/sanitizer";
import identifySource, {
  consolePrefix,
  getThemeInfo,
} from "discourse/lib/source-identifier";
import Ember from "ember";

const showingErrors = new Set();

export default {
  initialize(owner) {
    if (isTesting()) {
      return;
    }

    this.currentUser = owner.lookup("service:current-user");

    getAndClearUnhandledThemeErrors().forEach((e) => this.reportThemeError(e));

    document.addEventListener("discourse-error", this.handleDiscourseError);
  },

  teardown() {
    document.removeEventListener("discourse-error", this.handleDiscourseError);
    delete this.currentUser;
  },

  @bind
  handleDiscourseError(e) {
    if (e.detail?.themeId) {
      this.reportThemeError(e);
    } else {
      this.reportGenericError(e);
    }

    e.preventDefault(); // Mark as handled
  },

  reportThemeError(e) {
    const { themeId, error } = e.detail;
    const source = {
      type: "theme",
      ...getThemeInfo(themeId),
    };

    reportToConsole(error, source);
    reportToLogster(source.name, error);

    const message = I18n.t("themes.broken_theme_alert");
    this.displayErrorNotice(message, source);
  },

  reportGenericError(e) {
    const { messageKey, error } = e.detail;

    const message = I18n.t(messageKey);
    const source = identifySource(error);

    reportToConsole(error, source);

    if (messageKey && !showingErrors.has(messageKey)) {
      showingErrors.add(messageKey);
      this.displayErrorNotice(message, source);
    }
  },

  displayErrorNotice(message, source) {
    if (!this.currentUser?.admin) {
      return;
    }

    let html = `⚠️ ${message}`;

    if (source && source.type === "theme") {
      html += `<br/>${I18n.t("themes.error_caused_by", {
        name: escape(source.name),
        path: source.path,
      })}`;
    }

    html += `<br/><span class='theme-error-suffix'>${I18n.t(
      "themes.only_admins"
    )}</span>`;

    const alertDiv = document.createElement("div");
    alertDiv.classList.add("broken-theme-alert");
    alertDiv.innerHTML = html;
    document.body.prepend(alertDiv);
  },
};

function reportToLogster(name, error) {
  const data = {
    message: `${name} theme/component is throwing errors:\n${error.name}: ${error.message}`,
    stacktrace: error.stack,
  };

  // TODO: To be moved out into a logster-provided lib
  Ember.$.ajax(getURL("/logs/report_js_error"), {
    data,
    type: "POST",
  });
}

function reportToConsole(error, source) {
  const prefix = consolePrefix(error, source);
  if (prefix) {
    /* eslint-disable-next-line no-console */
    console.error(prefix, error);
  } else {
    /* eslint-disable-next-line no-console */
    console.error(error);
  }
}
