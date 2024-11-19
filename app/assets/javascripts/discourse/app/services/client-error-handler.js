import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import $ from "jquery";
import { getAndClearUnhandledThemeErrors } from "discourse/app";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import identifySource, {
  consolePrefix,
  getThemeInfo,
} from "discourse/lib/source-identifier";
import escape from "discourse-common/lib/escape";
import getURL from "discourse-common/lib/get-url";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

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

    const message = i18n("themes.broken_theme_alert");
    this.displayErrorNotice(message, source);
  }

  reportGenericError(e) {
    const { messageKey, error } = e.detail;

    const message = i18n(messageKey);
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

    if (source?.type === "theme") {
      html += `<br/>${i18n("themes.error_caused_by", {
        name: escape(source.name),
        path: source.path,
      })}`;
    } else if (source?.type === "plugin") {
      html += `<br/>${i18n("broken_plugin_alert", {
        name: escape(source.name),
      })}`;
    }

    html += `<br/><span class='theme-error-suffix'>${i18n(
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
  $.ajax(getURL("/logs/report_js_error"), {
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
