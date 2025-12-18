import { registerDeprecationHandler } from "@ember/debug";
import Service, { service } from "@ember/service";
import { addGlobalNotice } from "discourse/components/global-notice";
import DeprecationWorkflow from "discourse/deprecation-workflow";
import dasherize from "discourse/helpers/dasherize";
import { bind } from "discourse/lib/decorators";
import { registerDeprecationHandler as registerDiscourseDeprecationHandler } from "discourse/lib/deprecated";
import identifySource from "discourse/lib/source-identifier";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

const REPLACEMENT_URLS = {};

// Deprecation handling APIs don't have any way to unregister handlers, so we set up permanent
// handlers and link them up to the application lifecycle using module-local state.
let handler;
registerDeprecationHandler((message, opts, next) => {
  handler?.(message, opts);
  return next(message, opts);
});
registerDiscourseDeprecationHandler((message, opts) =>
  handler?.(message, opts)
);

export default class DeprecationWarningHandler extends Service {
  @service currentUser;
  @service siteSettings;

  #adminWarned = new Set();

  constructor() {
    super(...arguments);
    handler = this.handle;
  }

  willDestroy() {
    handler = null;
  }

  @bind
  handle(message, opts) {
    if (DeprecationWorkflow.shouldSilence(opts.id)) {
      return;
    }

    const source = opts.source || identifySource();
    if (source?.type === "browser-extension") {
      return;
    }

    this.maybeNotifyAdmin(opts, source);
  }

  maybeNotifyAdmin(opts, source) {
    if (!this.currentUser?.admin) {
      return;
    }

    if (!this.siteSettings.warn_critical_js_deprecations) {
      return;
    }

    if (DeprecationWorkflow.shouldNotifyAdmin(opts.id)) {
      this.notifyAdmin(opts, source);
    }
  }

  notifyAdmin({ id, url }, source) {
    if (this.#adminWarned.has(id)) {
      return;
    }

    this.#adminWarned.add(id);

    if (REPLACEMENT_URLS[id]) {
      url = REPLACEMENT_URLS[id];
    }

    let sourceString;
    if (source?.type === "theme") {
      sourceString = i18n("critical_deprecation.theme_source", {
        name: escapeExpression(source.name),
        path: source.path,
      });
    } else if (source?.type === "plugin") {
      sourceString = i18n("critical_deprecation.plugin_source", {
        name: escapeExpression(source.name),
      });
    } else {
      sourceString = i18n("critical_deprecation.unknown_source");
    }

    let notice =
      i18n("critical_deprecation.notice", {
        source: sourceString,
        id,
      }) + " ";

    if (url) {
      notice += i18n("critical_deprecation.learn_more_link", {
        url,
      });
    }

    if (this.siteSettings.warn_critical_js_deprecations_message) {
      notice += " " + this.siteSettings.warn_critical_js_deprecations_message;
    }

    addGlobalNotice(notice, `critical-deprecation--${dasherize(id)}`, {
      dismissable: true,
      dismissDuration: moment.duration(1, "day"),
      level: "warn",
    });
  }
}
