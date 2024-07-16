import { registerDeprecationHandler } from "@ember/debug";
import Service, { service } from "@ember/service";
import { addGlobalNotice } from "discourse/components/global-notice";
import identifySource from "discourse/lib/source-identifier";
import { escapeExpression } from "discourse/lib/utilities";
import { registerDeprecationHandler as registerDiscourseDeprecationHandler } from "discourse-common/lib/deprecated";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

// Deprecations matching patterns on this list will trigger warnings for admins.
// To avoid 'crying wolf', we should only add values here when we're sure they're
// not being triggered by core or official themes/plugins.
export const CRITICAL_DEPRECATIONS = [
  "discourse.modal-controllers",
  "discourse.bootbox",
  "discourse.add-header-panel",
  "discourse.header-widget-overrides",
  "discourse.plugin-outlet-tag-name",
  "discourse.plugin-outlet-parent-view",
  "discourse.d-button-action-string",
  /^(?!discourse\.)/, // All unsilenced ember deprecations
];

// Deprecation handling APIs don't have any way to unregister handlers, so we set up permenant
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

  #adminWarned = false;

  constructor() {
    super(...arguments);
    handler = this.handle;
  }

  willDestroy() {
    handler = null;
  }

  @bind
  handle(message, opts) {
    const workflowConfigs = window.deprecationWorkflow?.config?.workflow;
    const matchingConfig = workflowConfigs.find(
      (config) => config.matchId === opts.id
    );

    if (matchingConfig && matchingConfig.handler === "silence") {
      return;
    }

    const source = identifySource();
    if (source?.type === "browser-extension") {
      return;
    }

    this.maybeNotifyAdmin(opts, source);
  }

  maybeNotifyAdmin(opts, source) {
    if (this.#adminWarned) {
      return;
    }

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
    this.#adminWarned = true;

    let notice = I18n.t("critical_deprecation.notice") + " ";

    if (url) {
      notice += I18n.t("critical_deprecation.linked_id", {
        id: escapeExpression(id),
        url: escapeExpression(url),
      });
    } else {
      notice += I18n.t("critical_deprecation.id", {
        id: escapeExpression(id),
      });
    }

    if (this.siteSettings.warn_critical_js_deprecations_message) {
      notice += " " + this.siteSettings.warn_critical_js_deprecations_message;
    }

    if (source?.type === "theme") {
      notice +=
        " " +
        I18n.t("critical_deprecation.theme_source", {
          name: escapeExpression(source.name),
          path: source.path,
        });
    } else if (source?.type === "plugin") {
      notice +=
        " " +
        I18n.t("critical_deprecation.plugin_source", {
          name: escapeExpression(source.name),
        });
    }

    addGlobalNotice(notice, "critical-deprecation", {
      dismissable: true,
      dismissDuration: moment.duration(1, "day"),
      level: "warn",
    });
  }
}
