import { DEBUG } from "@glimmer/env";
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

// Deprecations matching patterns on this list will trigger warnings for admins.
// To avoid 'crying wolf', we should only add values here when we're sure they're
// not being triggered by core or official themes/plugins.
export const CRITICAL_DEPRECATIONS = [
  "discourse.modal-controllers",
  "discourse.bootbox",
  "discourse.add-header-panel",
  "discourse.header-widget-overrides",
  "discourse.add-flag-property",
  "discourse.breadcrumbs.childCategories",
  "discourse.breadcrumbs.firstCategory",
  "discourse.breadcrumbs.parentCategories",
  "discourse.breadcrumbs.parentCategoriesSorted",
  "discourse.breadcrumbs.parentCategory",
  "discourse.breadcrumbs.secondCategory",
  "discourse.qunit.acceptance-function",
  "discourse.qunit.global-exists",
  "discourse.post-stream.trigger-new-post",
  "discourse.plugin-outlet-classic-args-clash",
  "discourse.decorate-plugin-outlet",
  "discourse.component-template-resolving",
  "discourse.script-tag-hbs",
  "discourse.script-tag-discourse-plugin",
  "discourse.post-stream-widget-overrides",
  "discourse.widgets-end-of-life",
];

const REPLACEMENT_URLS = {};

if (DEBUG) {
  // used in system specs
  CRITICAL_DEPRECATIONS.push(/fake-deprecation.*/);
}

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

    if (
      CRITICAL_DEPRECATIONS.some((pattern) => {
        if (typeof pattern === "string") {
          return pattern === opts.id;
        } else {
          return pattern.test(opts.id);
        }
      })
    ) {
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
