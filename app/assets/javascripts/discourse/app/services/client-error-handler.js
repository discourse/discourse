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
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import Service, { inject as service } from "@ember/service";
import { getOwner } from "@ember/application";

const showingErrors = new Set();

@disableImplicitInjections
export default class ClientErrorHandlerService extends Service {
  @service currentUser;

  constructor() {
    super(...arguments);

    getAndClearUnhandledThemeErrors().forEach((e) => this.reportThemeError(e));

    document.addEventListener("discourse-error", this.handleDiscourseError);
  }

  get rootElement() {
    return document.querySelector(getOwner(this).rootElement);
  }

  willDestroy() {
    document.removeEventListener("discourse-error", this.handleDiscourseError);
    this.rootElement
      .querySelectorAll(".broken-theme-alert-banner")
      .forEach((e) => e.remove());
  }

  @bind
  handleDiscourseError(e) {
    if (e.detail?.themeId) {
      this.reportThemeError(e);
    } else {
      this.reportGenericError(e);
    }

    e.preventDefault(); // Mark as handled
  }

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
  }

  reportGenericError(e) {
    const { messageKey, error } = e.detail;

    const message = I18n.t(messageKey);
    const source = identifySource(error);

    reportToConsole(error, source);

    if (messageKey && !showingErrors.has(messageKey)) {
      showingErrors.add(messageKey);
      this.displayErrorNotice(message, source);
    }
  }

  displayErrorNotice(message, source) {
    if (!this.currentUser?.admin) {
      return;
    }

    let html = `⚠️ ${escape(message)}`;

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
    alertDiv.classList.add("broken-theme-alert-banner");
    alertDiv.innerHTML = html;
    this.rootElement.prepend(alertDiv);
  }
}

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
